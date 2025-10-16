# Automated verification of firmware
#
# conftest.py: Common scaffolding for verification tests
#
# Usage: pytest -v verify/ --firmware build/firmware
# Where:
# - verify/: Test script location
# - build/firmware: ELF file under test
#
# ELF parsing depends on pyelftools.
# Notes:
# - https://github.com/eliben/pyelftools/blob/main/doc/user-guide.rst
# - Field names are standard, but pyelftools sometimes maps their raw values (int) into names (str). But not consistently.
# - For reference, check fields names and value names in the gABI, e.g. here: https://gabi.xinuos.com/elf/05-symtab.html
# - Check the C-styled enum mapping in pyelftools/elf/enums.py.
# - The parser is a faithful decoder of the ELF structure, but doesn't feel like a reasonable model of ELF semantics.
# - Consider LIEF instead of pyelftools in the future.
#
# Janus, October 2025

import os

import pytest
from dataclasses import dataclass
from typing import Any, List, Dict
from typing import cast

from elftools.elf.elffile import ELFFile
from elftools.elf.sections import Symbol as ElfSymbolTableEntry
from elftools.elf.sections import Section as ElfSectionTableEntry
from elftools.elf.sections import ARMAttributesSection
from elftools.elf.descriptions import describe_sh_flags, describe_e_machine, describe_ei_data, describe_ei_class
from elftools.elf.constants import SH_FLAGS, E_FLAGS
from elftools.elf.enums import ENUM_E_MACHINE, ENUM_EI_DATA


# --- Pass in firmware as a CLI option ---
FIRMWARE_OPTION = "--firmware"
def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        FIRMWARE_OPTION,
        action="store",
        help="Path to firmware ELF for verification",
        required=True
    )

# --- elftools uses references into an open file, so our dataclasses detach data from that file ---
@dataclass
class Header:
    """
    Represents the ELF file header.
    Ref. e.g. https://gabi.xinuos.com/elf/02-eheader.html
    """
    ei_class: str
    ei_data: str
    e_machine: str
    e_flags: int

    @classmethod
    def from_elf(cls, elf: ELFFile) -> "Header":
        hdr = elf.header
        
        e_ident = hdr["e_ident"]
        e_machine = hdr["e_machine"]

        return cls(
            ei_class=str(e_ident["EI_CLASS"]),
            ei_data=str(e_ident["EI_DATA"]),
            e_machine=str(e_machine),
            e_flags=int(hdr["e_flags"])
        )


@dataclass
class ArmAttributes:
    """Refer to AAELF32 sec. 6.1.1"""
    tags: Dict[str, str]

    @classmethod
    def from_elf(cls, elf: ELFFile) -> "ArmAttributes":
        sec: ARMAttributesSection = elf.get_section_by_name(".ARM.attributes")  # type: ignore



        tags = {}
        for subsection in sec.subsections:
            for subsub in subsection.subsubsections:
                for attr in subsub.attributes:
                    tags[str(attr.tag)] = attr.value

        return cls(
            tags=tags
        )


@dataclass
class Symbol:
    """
    Represents a single symbol from the Symbol table
    Ref. e.g. https://gabi.xinuos.com/elf/05-symtab.html
    """
    name: str
    typ: str
    bind: str
    shndx: str | int
    addr: int
    size: int

    @classmethod
    def from_elf(cls, elf_sym: ElfSymbolTableEntry) -> "Symbol":
        info = elf_sym["st_info"]
        return cls(
            name=str(elf_sym.name),
            typ=str(info["type"]),      # nested in the st_*, but not in the sh_*
            bind=str(info["bind"]),
            shndx=elf_sym["st_shndx"],
            addr=int(elf_sym["st_value"]),
            size=int(elf_sym["st_size"])
        )

@dataclass
class Section:
    """
    Represents a single Section from section header table
    Ref. e.g. Ref. e.g. https://gabi.xinuos.com/elf/03-sheader.html
    """
    name: str
    typ: str
    flags_bits: int
    flags_str: str
    addr: int
    size: int
    align: int

    @classmethod
    def from_elf(cls, elf_sec: ElfSectionTableEntry) -> "Section":
        header = elf_sec.header
        flag_bits = header["sh_flags"]
        return cls(
            name=str(elf_sec.name),
            typ=str(header["sh_type"]),
            flags_bits=flag_bits,
            flags_str=describe_sh_flags(flag_bits),
            addr=int(header["sh_addr"]),
            size=int(header["sh_size"]),
            align=int(header["sh_addralign"])
        )
    
    @property
    def is_allocatable(self) -> bool:
        return bool(self.flags_bits & SH_FLAGS.SHF_ALLOC)
    
    @property
    def is_writable(self) -> bool:
        return bool(self.flags_bits & SH_FLAGS.SHF_WRITE)
    
    @property
    def is_executable(self) -> bool:
        return bool(self.flags_bits & SH_FLAGS.SHF_EXECINSTR)





class ParsedElf:
    __slots__ = ("elf_path", "header", "arm_attributes", "sections", "symbols")
    
    elf_path: str
    header: Header
    arm_attributes: ArmAttributes
    sections: Dict[str, Section]
    symbols: Dict[str, List[Symbol]]       # Symbol names are not necessarily unique in the symbol table.

    def __init__(self, cfg: pytest.Config):
        self.elf_path: str = self._validated_path(cfg)
        self._parse_elf_to_members()


    def _parse_elf_to_members(self) -> None:
        with open(self.elf_path, "rb") as f:
            elf_file = ELFFile(f)
            self._parse_header_to_member(elf_file)
            self._parse_arm_attributes_to_member(elf_file)
            self._parse_symbol_table_to_member(elf_file)
            self._parse_section_table_to_member(elf_file)
    

    def _validated_path(self, cfg: pytest.Config) -> str:
        """Checks existence of the ELF specified for test, and return its validated path."""
        p = cfg.getoption(FIRMWARE_OPTION)
        if not os.path.isfile(p):
            raise pytest.UsageError(f"{FIRMWARE_OPTION} {p} does not exist.")
        return p


    def _parse_header_to_member(self, elf_file: ELFFile) -> None:
        """
        Populates ELF file metadata.
        """
        self.header = Header.from_elf(elf_file)


    def _parse_arm_attributes_to_member(self, elf_file: ELFFile) -> None:
        """
        Populates ARM attributes.
        """
        self.arm_attributes = ArmAttributes.from_elf(elf_file)


    def _parse_symbol_table_to_member(self, elf_file: ELFFile) -> None:
        """
        Populates object's symbols member from an ELFFile.
        - Skips the undefined symbol index (STN_UNDEF).
        - Ignores STT_FILE (associated source file), STT_SECTION (referential to sections),
          STT_NOTYPE (unspecified type).
        - Ignores ARM symbols ($a/$t, $d, $x)
        """
        self.symbols = {}
        symbol_table = elf_file.get_section_by_name(".symtab")

        for _sym in symbol_table.iter_symbols():        # type: ignore
            sym = Symbol.from_elf(_sym)

            # Reasons for not including the symbol
            if sym.shndx == "SHN_UNDEF" or \
               sym.typ in ("STT_FILE", "STT_SECTION") or \
               sym.name.startswith("$"):
                continue

            self.symbols.setdefault(sym.name, []).append(sym)


    def _parse_section_table_to_member(self, elf_file: ELFFile) -> None:
        """
        Populates object's sections member from an ELFFile.
        - Keep sections that map to hardware (SHF_ALLOC).
        - Keep ARM metadata (ARM.attributes*).
        - Omit symbol table (treated separately).
        - Omit our own metadata (.debug, .note, etc.).
        - Omit tool metadata (relocations).
        - Omit undefined sections (SHN_UNDEF).
        """
        self.sections = {}

        for _sec in elf_file.iter_sections():
            sec = Section.from_elf(_sec)

            if sec.is_allocatable or sec.name.startswith((".ARM.attributes")):
                self.sections[sec.name] = sec        # Save section

            elif not sec.is_allocatable or sec.name.startswith((".symtab", ".debug", ".note")):
                continue                            # Explicitly skip section


    def require_unique_symbol(self, symbol_name: str) -> Symbol:
        """
        Return the unique Symbol with the given name.
        
        Raises:
            pytest.UsageError: if the symbol is missing, duplicated or wrong type.
        """
        sym_list = self.symbols.get(symbol_name)

        if not sym_list:    # None or []
            raise pytest.UsageError(f"Symbol '{symbol_name}' does not exist in ELF.")
        
        if len(sym_list) > 1:
            raise pytest.UsageError(f"Symbol '{symbol_name}' is not uniquely named ({len(sym_list)} entries).")

        sym = sym_list[0]
        if not isinstance(sym, Symbol):
            raise pytest.UsageError(f"Symbol '{symbol_name}' has invalid type '{type(sym).__name__}'")
        
        return sym


    def require_section(self, section_name: str) -> Section:
        """
        Return the Section with the given name.
        
        Raises:
            pytest.UsageError: if the section is missing or wrong type.
        """
        sec = self.sections.get(section_name)

        if not sec:
            raise pytest.UsageError(f"Section '{section_name}' does not exist in ELF.")
        
        if not isinstance(sec, Section):
            raise pytest.UsageError(f"Symbol '{section_name}' has invalid type '{type(sec).__name__}'")
        
        return sec


    def has_symbol(self, symbol_name: str) -> bool:
        return symbol_name in self.symbols


    def has_section(self, section_name: str) -> bool:
        return section_name in self.sections
    
    # def has_cpp_runtime(self) -> bool:
    #     """Indication of support for C++"""
    #     cpp_indicators = ("__cxa_atexit", "__dso_handle", "_Z")
    #     for name in self.symbols:
    #         if name.startswith(cpp_indicators):
    #             return True
    #     return False
    

# --- Fixtures ---
@pytest.fixture(scope="session")
def parsed_elf(pytestconfig: pytest.Config) -> ParsedElf:
    return ParsedElf(pytestconfig)
