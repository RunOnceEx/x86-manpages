#!/bin/bash

# for i in $(ls ~/projects/x86-manpages/felix-x86/www.felixcloutier.com/x86-tmp); do ./doit.sh ~/projects/x86-manpages/felix-x86/www.felixcloutier.com/x86-tmp/$i; done

REMOVE_PATTERN() {
        sed -i -e "s/$1//g" "$2"
}
REMOVE_LINE_FROM_PATTERN() {
        sed -i -e "/$1/d" "$2"
}

# Write header, date etc. to man page
GENERATE_HEADER() {
        TMP=$(grep "\.TH" "$1" | sed -e "s/.TH //")                     # ".TH JMP — JUMP" --> "JMP — JUMP"
        TMP=$(echo -e "$TMP" | sed -e "s/\//-/g")                       # replace slashes with dash
        TITLE=$(echo -e "$TMP" | sed -e "s/ — /\n/g" | head -n 1)       # JMP
        HEADER=$(echo -e "$TMP" | sed -e "s/ — /\n/g" | tail -n 1)      # JUMP
        DATE="May 2019"                                                 # Constant, from last processed intel manual
        NEW_TH=".TH \"X86-$TITLE\" \"7\" \"$DATE\" \"TTMO\" \"Intel x86-64 ISA Manual\""
        NAME="\\n.SH NAME\\n$TITLE - $HEADER"
        sed -i "s/\.TH.*/$NEW_TH$NAME/" "$1"                            # replace line with new TH
}

# colophone generator works with ugly html
GENERATE_COLOPHON() {
        SEEALSO="<h2>SEE ALSO<\/h2> x86-manpages(7) for a list of other x86-64 man pages."
        sed -i "s/This UNOFFICIAL/$SEEALSO<h2>COLOPHON<\/h2> This UNOFFICIAL/" $1
}

FILE=$1

# work on the temporary file
cp "$FILE" "$FILE.tmp"
FILE="$FILE.tmp"

# beautify html source
cat "$FILE" | htmlbeautifier -t 4 > "$FILE.beautiful"

# normalize rowspans
./rowspan-normalizer.sh "$FILE.beautiful"

# uglify html source (to remove line breaks)
cat "$FILE.beautiful" | ~/node_modules/html-minifier/cli.js --collapse-whitespace > "$FILE.ugly"

# remove some unwanted tags
./tag-remover.sh "$FILE.ugly" header

# generate colophon
GENERATE_COLOPHON "$FILE.ugly"

# beautify the uglified
cat "$FILE.ugly"| htmlbeautifier -t 4 > $FILE

# remove unwanted tags that break go-md2man
./tag-remover.sh "$FILE" sup
./tag-remover.sh "$FILE" em
./tag-remover.sh "$FILE" strong
./tag-remover.sh "$FILE" a

# meanwhile, uppercase h1's and h2's
./tag-content-uppercaser.sh "$FILE" h1
./tag-content-uppercaser.sh "$FILE" h2

# convert html to markdown
pandoc -f html -t markdown_strict+pipe_tables "$FILE" -o "$FILE.md"

# convert markdown to roff
cat "$FILE.md" | go-md2man > "$FILE.7"

# remove some chars
REMOVE_PATTERN " ¶" "$FILE.7" # delete this char
REMOVE_LINE_FROM_PATTERN "\\\fB\\\fC\\\fR" "$FILE.7" # delete empty table rows
GENERATE_HEADER "$FILE.7"

# append to colophon
echo -e "\n.br\nThis page is generated by scripts; therefore may contain visual or semantical bugs. Please report them (or better, fix them) on https://github.com/ttmo-O/x86-manpages.">> "$FILE.7"
echo -e "\n.br\nMIT licensed by TTMO $(date +%Y) (Turkish Unofficial Chamber of Reverse Engineers - https://ttmo.re).">> "$FILE.7"

# rename output
TITLE_LOWERCASE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed "s/ //g") # remove space in filename
# this loop is needed to generate e.g. 4 seperate files for "VSCATTERPF0DPS-VSCATTERPF0QPS-VSCATTERPF0DPD-VSCATTERPF0QPD" page
for i in $(echo $TITLE_LOWERCASE | sed "s/-/\n/g"); do
        OUTPUT="x86-$i.7"
        cp "$FILE.7" $OUTPUT
        echo "Done $OUTPUT"
done

# remove artifacts
rm "$FILE.7" "$FILE.beautiful" "$FILE.ugly" "$FILE.md" "$FILE"

#man -l "$OUTPUT"
