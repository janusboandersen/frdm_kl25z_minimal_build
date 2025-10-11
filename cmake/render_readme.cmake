# Render the readme file with Mermaid included
# Turns out we need slightly different blocks depending on the type of either .mmd or .md, so this file is very manual

# The readme template contains marked-up tags
file(READ "${README_TEMPLATE}" README_TEXT)


# Each marked up tag should be replaced by text stored in a file. 
# First get that text.
file(READ "${DIAGRAM1}" DIAGRAM1_TEXT)

# Then format it as a block for markdown
set(MERMAID_BLOCK1 "```mermaid\n${DIAGRAM1_TEXT}\n```")

# And finally perform the replacment into the template
string(REPLACE "@@DIAGRAM1@@" "${MERMAID_BLOCK1}" README_FILLED "${README_TEXT}")


# ...and so on for all the other diagrams ...
file(READ "${DIAGRAM2}" DIAGRAM2_TEXT)
set(MERMAID_BLOCK2 "```\n${DIAGRAM2_TEXT}\n```")
string(REPLACE "@@DIAGRAM2@@" "${MERMAID_BLOCK2}" README_FILLED "${README_FILLED}")

file(READ "${DIAGRAM3}" DIAGRAM3_TEXT)
set(MERMAID_BLOCK3 "```\n${DIAGRAM3_TEXT}\n```")
string(REPLACE "@@DIAGRAM3@@" "${MERMAID_BLOCK3}" README_FILLED "${README_FILLED}")

file(READ "${DIAGRAM4}" DIAGRAM4_TEXT)
set(MERMAID_BLOCK4 "```\n${DIAGRAM4_TEXT}\n```")
string(REPLACE "@@DIAGRAM4@@" "${MERMAID_BLOCK4}" README_FILLED "${README_FILLED}")

file(READ "${DIAGRAM5}" DIAGRAM5_TEXT)
set(MERMAID_BLOCK5 "```\n${DIAGRAM5_TEXT}\n```")
string(REPLACE "@@DIAGRAM5@@" "${MERMAID_BLOCK5}" README_FILLED "${README_FILLED}")

file(READ "${DIAGRAM6}" DIAGRAM6_TEXT)
set(MERMAID_BLOCK6 "```mermaid\n${DIAGRAM6_TEXT}\n```")
string(REPLACE "@@DIAGRAM6@@" "${MERMAID_BLOCK6}" README_FILLED "${README_FILLED}")

file(READ "${DIAGRAM7}" DIAGRAM7_TEXT)
set(MERMAID_BLOCK7 "```mermaid\n${DIAGRAM7_TEXT}\n```")
string(REPLACE "@@DIAGRAM7@@" "${MERMAID_BLOCK7}" README_FILLED "${README_FILLED}")


# Output the populated README
file(WRITE "${README_OUT}" "${README_FILLED}")