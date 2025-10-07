# Render the readme file with Mermaid included

# inputs: 
#   -DDIAGRAM= 
#   -DREADME_TEMPLATE= 
#   -DREADME_OUT=

# Get the tamplate contents
file(READ "${README_TEMPLATE}" README_TEXT)

# Get the diagrams and create the pastable sections
file(READ "${DIAGRAM1}" DIAGRAM1_TEXT)
set(MERMAID_BLOCK1 "```mermaid\n${DIAGRAM1_TEXT}\n```")

# Parse the README template, and interpolate the insertions stepwise
string(REPLACE "@@DIAGRAM1@@" "${MERMAID_BLOCK1}" README_FILLED "${README_TEXT}")

# ...and so on...
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


# Output the populated template
file(WRITE "${README_OUT}" "${README_FILLED}")