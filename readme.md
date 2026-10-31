HEXED (Horribly EXcruciating EDitor)

TODO:

BUGS

COMMANDS

c is the same as d except it cuts the text instead of deleting it

f followed by character to jump to on the screen. Each frame replaces the following char with a unique symbol for jumping to that char

p for put

r to redo

u to undo

v to highlight similar to vim

y for yank

wq to save and quit with spaces

wt to save the file with tab indenting

ww to save the file with space indenting

/ to search for a string and , for backwards and . for forwards

; to repeat the last command

] opens up a directory tree navigated by typing directory and filenames and creates a buffer copy for the current tile

[ opens up a list of existing buffers to attach to the current tile

FEATURES

\t to 4 spaces on buffer creation

Writing a buffer to a file

A unique word scrambler for fast jump, file tree, and buffer navigation

Number for repeating action

Action History for macros and repeating actions

Buffers need their own history for undo and redo

Running the program with filename args for buffer setup

