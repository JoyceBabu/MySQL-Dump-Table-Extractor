#!/bin/bash
#
# MySQL Dumpfile Table Extractor v1.0
#  
# This script can be used to extract tables from a MySQL dumpfile
#
# Copyright 2010, Joyce Babu ( http://www.joycebabu.com/ )
# Released under the MIT, BSD and GPL Licenses.
#
# Visit http://www.joycebabu.com/blog/extract-tables-from-mysql-dumpfile.html for updates
#
# First release 2010-12-02


get_dump_file(){
	echo "Enter the path to your dump file. Type QUIT to exit."
	while [ -z $DUMP_FILE ]; do
		echo -n "> "
		read INPUT
		if [ $INPUT = "QUIT" ]; then
			exit_success
			exit 0
		else
			check_dump_file $INPUT
			if [ $? -eq 0 ]; then
				DUMP_FILE=$INPUT
			fi
		fi
	done
}

check_dump_file(){
	local INPUT=$1
	if [ -z $INPUT ]; then
		echo "[Error] Filename cannot be empty"
	elif [ ! -f $INPUT ]; then
		echo "[Error] $INPUT does not exist"
	elif [ ! -r $INPUT ]; then
		echo "[Error] $INPUT is not readable"
	else
		return 0
	fi
	return 1
}

generate_table_list(){
	local DUMP_FILE=$1
	echo "Generating list of tables in $DUMP_FILE"
	i=0
	for table in `grep 'Table structure' "$DUMP_FILE" | cut -d'\`' -f2`; do
		TABLE_LIST[$i]=$table
		i=$(($i+1))
	done
	TABLE_COUNT=$i

	if [ $TABLE_COUNT -lt 1 ]; then
		echo "[ERROR] $DUMP_FILE is not a valid mysqldump file."
		return 1
	else
		return 0
	fi
}

extract(){
	local DUMP_FILE=$1
	local INPUT1=$2
	local INPUT2=$3

	# Check whether input is numeric
	expr $INPUT1 + 1 2> /dev/null
	if [ $? = 0 ]; then
		# Get array index
		index1=$(($INPUT1-1))
	else
		# Tablename is specified. Search for index.
		for index1 in "${!TABLE_LIST[@]}" ""; do [[ ${TABLE_LIST[index1]} = $INPUT1 ]] && break; done
	fi
	
	# Input 2
	if [ ! -z $INPUT2 ]; then
		# Check whether input is numeric
		expr $INPUT2 + 1 2> /dev/null
		if [ $? = 0 ]; then
			# Get array index
			index2=$(($INPUT2-1))
		else
			# Tablename is specified. Search for index.
			for index2 in "${!TABLE_LIST[@]}" ""; do [[ ${TABLE_LIST[index2]} = $INPUT2 ]] && break; done
		fi
	else 
		# not specified. use INPUT1
		index2=$index1
	fi
	
	if [ -z $index1 ]; then
		echo "[ERROR] Invalid input '$INPUT1'. Not a valid table or index."
	elif [ -z $index2 ]; then
		echo "[ERROR] Invalid input '$INPUT2'. Not a valid table or index."
	else
		# Ensure index1 <= index2
		if [ $index1 -gt $index2 ]; then
			tmp=$index1
			index1=$index2
			index2=$tmp
		fi

		TABLE1=${TABLE_LIST[index1]}
		BEGIN_PATTERN="/-- Table structure for table .$TABLE1./"
		# Increment index2 to find the next tablename
		index2=$(($index2+1))
		count=$(($index2-$index1))
		if [ $index2 -lt $TABLE_COUNT ]; then
			TABLE2=${TABLE_LIST[index2]}
			END_PATTERN="/-- Table structure for table .$TABLE2./"
		else
			END_PATTERN='$'
		fi

		OUTPUT_FILE="$TABLE1.sql"
		i=1
		while [ -s $OUTPUT_FILE ]; do
			OUTPUT_FILE="$TABLE1.sql.$i"
			i=$(($i+1))
		done
		# Extract the tables
		
		sed -ne "${BEGIN_PATTERN},${END_PATTERN}p" $DUMP_FILE > $OUTPUT_FILE

		if [ -s $OUTPUT_FILE ]; then
			if [ $count -eq 1 ]; then
				echo "[SUCCESS] Table '$TABLE1' was extracted to $OUTPUT_FILE"
			else
				echo "[SUCCESS] Following $count tables were extracted to $OUTPUT_FILE"
				for ((i=$(($index1+1)); i <= index2 ; i++)); do
				  echo "$i. ${TABLE_LIST[i-1]}"
				done
			fi
			return 0
		else
			echo "[ERROR] Failed to extract table"
		fi
	fi
	return 1
}

exit_success(){
	echo "=============================================================================="
	echo "| Thank you for using the script. For updates visit                          |"
	echo "| http://www.joycebabu.com/blog/extract-tables-from-mysql-dumpfile.html      |"
	echo "=============================================================================="
}

TABLE_COUNT=0

echo "=============================================================================="
echo "| Welcome to mysql table extraction script.                                  |"
echo "=============================================================================="

# If filename and tablename were specified from commandline, extract and exit
if [ $# -ge 2 ]; then
	check_dump_file $1
	if [ $? -eq 0 ]; then
		generate_table_list $1
	fi
	if [ $? -eq 0 ]; then
		extract $1 $2 $3
	fi
	exit $?
fi

# Get the filename if not already specified
if [ -z $1 ]; then
	echo "You have not specified a file name to extract tables."
	get_dump_file
else
	DUMP_FILE=$1
fi

# Generate table list and wait for user input
while [ $TABLE_COUNT -le 0 ]; do
	generate_table_list $DUMP_FILE
	if [ $? -ne 0 ]; then
		get_dump_file
	fi
done

# List the tables
INPUT="LIST"

while [ 1 ]; do
	if [ $INPUT = "QUIT" ]; then
		exit_success
		exit 0
	elif [ $INPUT = "LIST" ]; then
		for ((i=1; i <= TABLE_COUNT ; i++)); do
		  echo "$i. ${TABLE_LIST[i-1]}"
		done
	else
		extract $DUMP_FILE $INPUT $INPUT2
	fi
	echo ""
	echo "=============================================================================="
	echo "| Usage:                                                                     |"
	echo "|     tablename              [ Extracts single table by tablename or index ] |"
	echo "|     tablename1 tablename2  [ Extracts all tables from table1 table2      ] |"
	echo "|     LIST                   [ List all tables                             ] |"
	echo "|     QUIT                   [ Exit from script                            ] |"
	echo "=============================================================================="
	echo -n "> "
	read INPUT INPUT2
	echo ""
done


