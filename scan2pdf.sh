#!/bin/bash
set -u          # fail on undefined variable

: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ESC=255}

declare -a files=("/home/milan/x/test/ikea1.jpg" "/home/milan/x/test/ikea2.jpg" "/home/milan/x/test/hornbach.jpg")
declare files_dlg_formatted
declare g_return_code
declare mogrify=1
declare density="200x200"
declare quality="50"
declare paper_format="a4paper"
declare paper_orientation="portrait"

update_files_dlg_formatted() {
    files_dlg_formatted=""
    if [[ ${#files[@]} -eq 0 ]]; then
        files_dlg_formatted="NO_FILES 1 1 - 1 10 40 0"
        return
    fi
    let i=1
    for file in ${files[@]}; do
        files_dlg_formatted="${files_dlg_formatted} ${i}: ${i} 1 ${file} ${i} 10 40 0 "
        let i=i+1
    done
}

show_add_file_dlg() {
    local return_code=0
    local folder="/home/milan"
    while true; do
        exec 3>&1
        file=$(dialog --clear --title "Please choose an image file" --fselect "${folder}/" 14 48 2>&1 1>&3)
        return_code=$?
        exec 3>&-
        
        if [[ ${return_code} -eq ${DIALOG_CANCEL} || ${return_code} -eq ${DIALOG_ESC} ]]; then
            break
        fi
        
        if [[ -d ${file} ]]; then
            folder=$(realpath ${file})
            continue
        fi
        
        if [[ -f ${file} ]]; then
            f=$(realpath ${file})
            files+=(${f})
            update_files_dlg_formatted
            break
        fi
    done
}

show_files_dlg() {
    local return_code=0
    while true; do
        exec 3>&1
        dialog --ok-label "Continue" \
        --default-button "extra" \
        --extra-button --extra-label "Add image" \
        --backtitle "scan2pdf - convert scanned files into PDF" \
        --form "Files" \
        20 50 0 $(echo -n ${files_dlg_formatted}) 2>&1 1>&3
        return_code=$?
        exec 3>&-
        
        if [[ ${return_code} -eq  ${DIALOG_EXTRA} ]] ; then
            show_add_file_dlg
            continue
        fi
        g_return_code=${return_code}
        break;
    done
}

show_mogrify_dlg()  {
    local return_code=0
    exec 3>&1
    value=$(dialog --clear --backtitle "scan2pdf - convert scanned files into PDF" \
        --title "mogrify" "$@" \
        --checklist "Choose whether you want to mogrify the images." 20 61 1 \
    "mogrify"  "" on 2>&1 1>&3)
    retval=$?
    exec 3>&-
    
    g_return_code=${return_code}
    if [[ ${return_code} -eq  ${DIALOG_OK} ]]; then
        if [[ $value -eq "mogrify" ]]; then
            mogify=1
        else
            mogify=0
        fi
    fi
    
}

show_density_dlg()  {
    local return_code=0
    exec 3>&1
    value=$(dialog --clear --backtitle "scan2pdf - convert scanned files into PDF" \
        --title "Density" "$@" \
        --radiolist "Choose the image density." 20 61 5 \
        "100x100"  "" off \
        "150x150"  "" off \
        "200x200"  "" on \
        "300x300"  "" off \
    "400x400"  "" off  2>&1 1>&3)
    retval=$?
    exec 3>&-
    
    g_return_code=${return_code}
    if [[ ${return_code} -eq  ${DIALOG_OK} ]]; then
        density=${value}
    fi
}

show_quality_dlg()  {
    local return_code=0
    exec 3>&1
    value=$(dialog --clear --backtitle "scan2pdf - convert scanned files into PDF" \
        --title "Quality" "$@" \
        --radiolist "Choose the image qaulity (the bigger the better)." 20 61 5 \
        "40"  "" off \
        "50"  "" off \
        "60"  "" on \
        "70"  "" off \
    "80"  "" off  2>&1 1>&3)
    retval=$?
    exec 3>&-
    
    g_return_code=${return_code}
    if [[ ${return_code} -eq  ${DIALOG_OK} ]]; then
        quality=${value}
    fi
}

show_paper_format_dlg()  {
    local return_code=0
    exec 3>&1
    value=$(dialog --clear --backtitle "scan2pdf - convert scanned files into PDF" \
        --title "Paper format" "$@" \
        --radiolist "Choose the paper format." 20 61 3 \
        "a5paper"  "" off \
        "a4paper"  "" on \
    "a3paper"  "" off 2>&1 1>&3)
    retval=$?
    exec 3>&-
    
    g_return_code=${return_code}
    if [[ ${return_code} -eq  ${DIALOG_OK} ]]; then
        paper_format=${value}
    fi
}

show_paper_orientation_dlg()  {
    local return_code=0
    exec 3>&1
    value=$(dialog --clear --backtitle "scan2pdf - convert scanned files into PDF" \
        --title "Paper orientation" "$@" \
        --radiolist "Choose the paper orientaion." 20 61 2 \
        "portrait"  "" on \
    "landscape"  "" off 2>&1 1>&3)
    retval=$?
    exec 3>&-
    
    g_return_code=${return_code}
    if [[ ${return_code} -eq  ${DIALOG_OK} ]]; then
        paper_orientation=${value}
    fi
}

do_convert() {
    random=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-5} | head -n 1)
    work="work_${random}"
    echo "Working directory ${work}"
    mkdir -p "./${work}"
    
    # copy files
    for file in ${files[@]}; do
        cp ${file} ${work}/
    done
    pushd ${work} >> /dev/null

    # mogrify
    if [[ ${mogrify} -eq 1 ]]; then    
        for file in ${files[@]}; do
            mogrify -normalize -level 10%,90% -sharpen 0x1 ${file};
        done    
    fi

    # compress
    for file in ${files[@]}; do
        convert -density ${density} -quality ${quality} -compress jpeg ${file} ${file}       
    done
      
    #convert to pdf
    let i=1
    for file in ${files[@]}; do
        pdf=$(printf "%05d\n" ${i})
        convert ${file} "${pdf}.pdf"; 
         let i=i+1
    done
    
    #pdfunite
    pdfunite *.pdf complete.pdf

    #pdfjam
    local orient="landscape"
    if [[ "${paper_orientation}" == "portrait" ]]; then   
        orient="no-landscape"
    fi
    pdfjam complete.pdf --${paper_format} --${orient} --outfile complete2.pdf

    #ocr
    ocrmypdf -l ces --output-type=pdf complete2.pdf complete3.pdf

    popd >> /dev/null
}

main() {
    update_files_dlg_formatted
    show_files_dlg
    
    if [[ ${g_return_code} -eq ${DIALOG_OK} ]]; then
        
        # if [[ ${#files[@]} -eq 0 ]]; then
        #     # echo "No images selected."
        #     # return
        # fi
        show_mogrify_dlg
    else
        return
    fi
    
    if [[ ${g_return_code} -eq ${DIALOG_OK} ]]; then
        show_density_dlg
    else
        return
    fi
    
    if [[ ${g_return_code} -eq ${DIALOG_OK} ]]; then
        show_quality_dlg
    else
        return
    fi
    
    if [[ ${g_return_code} -eq ${DIALOG_OK} ]]; then
        show_paper_format_dlg
    else
        return
    fi
    
    if [[ ${g_return_code} -eq ${DIALOG_OK} ]]; then
        show_paper_orientation_dlg
    else
        return
    fi
    
    echo "Converting ..."
    do_convert
}


main "${@}"
