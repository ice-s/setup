#!/bin/bash

PS3="Select item please: "

items=("Item 1" "Item 2" "Item 3")

select item in "${items[@]}" Quit
do
    case $REPLY in
        1) echo "Selected item #$REPLY which means $item";;
        2) echo "Selected item #$REPLY which means $item";;
        3) echo "Selected item #$REPLY which means $item";;
        $((${#items[@]}+1))) echo "We're done!"; break;;
        *) echo "Ooops - unknown choice $REPLY";;
    esac
done