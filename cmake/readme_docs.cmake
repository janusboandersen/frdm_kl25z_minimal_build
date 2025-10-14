# --------------------------
# Documentation renderer
# --------------------------


set(DIAGRAM1         ${CMAKE_SOURCE_DIR}/docs/diagrams/build_pipeline.mmd)
set(DIAGRAM2         ${CMAKE_SOURCE_DIR}/docs/diagrams/target_sram_layout.md)
set(DIAGRAM3         ${CMAKE_SOURCE_DIR}/docs/diagrams/target_flash_layout.md)
set(DIAGRAM4         ${CMAKE_SOURCE_DIR}/docs/diagrams/abi_contracts.md)
set(DIAGRAM5         ${CMAKE_SOURCE_DIR}/docs/diagrams/build_transformations.md)
set(DIAGRAM6         ${CMAKE_SOURCE_DIR}/docs/diagrams/flash_pipeline.mmd)
set(DIAGRAM7         ${CMAKE_SOURCE_DIR}/docs/diagrams/debug_pipeline.mmd)
set(README_TEMPLATE  ${CMAKE_SOURCE_DIR}/docs/README_template.md)
set(RENDER_SCRIPT    ${CMAKE_SOURCE_DIR}/cmake/render_readme.cmake)
set(README_OUT       ${CMAKE_SOURCE_DIR}/README.md)

# Rule to generate README.md
add_custom_command(
  OUTPUT ${README_OUT}
  COMMAND ${CMAKE_COMMAND}
          -DDIAGRAM1=${DIAGRAM1}
          -DDIAGRAM2=${DIAGRAM2}
          -DDIAGRAM3=${DIAGRAM3}
          -DDIAGRAM4=${DIAGRAM4}
          -DDIAGRAM5=${DIAGRAM5}
          -DDIAGRAM6=${DIAGRAM6}
          -DDIAGRAM7=${DIAGRAM7}
          -DREADME_TEMPLATE=${README_TEMPLATE}
          -DREADME_OUT=${README_OUT}
          -P ${RENDER_SCRIPT}
  DEPENDS ${README_TEMPLATE} ${RENDER_SCRIPT}
  COMMENT "Rendering README.md from ${README_TEMPLATE}"
  VERBATIM
)

# Target you can run: `ninja readme` (or `cmake --build . --target readme`)
add_custom_target(readme DEPENDS ${README_OUT})