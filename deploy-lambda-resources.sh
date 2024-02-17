#!/bin/bash

# File path
file_path="hashes.json"
old_file_path="hashes-old.json"
LAMBDA_DIR_PATH='./aws/lambda/'
WORK_DIR=$(pwd)
lambda_bucketname=$(aws ssm get-parameter --region "us-east-1" --name "/tb/develop/lambdabucketname" --with-decryption --query "Parameter.Value" --output text)
TBAPISYSTEMACCESSKEY_var=$(aws ssm get-parameter --region "us-east-1" --name "/tb/develop/ACCESS_KEY_SYSTEM" --with-decryption --query "Parameter.Value" --output text)
TB_APIURL_var=$(aws ssm get-parameter --region "us-east-1" --name "/tb/develop/WEB_PORTAL_URL" --with-decryption --query "Parameter.Value" --output text)

#####################################################################################################################################
#                                                   Create Lambda folders hashes                                                    #
#####################################################################################################################################
create_hashes() {

	AWS_S3_BUCKET=$lambda_bucketname
	AWS_LAMBDA_DIR='./aws/lambda'
	HASHES_JSON_FILE='hashes.json'
	OLD_HASHES_JSON_FILE='hashes-old.json'

	# Check if the lambda directory exists
if [ -d "$AWS_LAMBDA_DIR" ]; then
    	# Use find to list all directories at one level inside $AWS_LAMBDA_DIR excluding the base directory
    	directories=$(find "$AWS_LAMBDA_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -u)

    	# Count the number of directories
    	num_directories=$(echo "$directories" | wc -l)


    	# Print the names of the directories

    	# Declare an associative array to store new hashes
    	declare -A directory_hashes_new

    	# Loop through each directory and calculate the hash
    	for dir in $directories; do
            # Check if the directory exists
        	if [ -d "$AWS_LAMBDA_DIR/$dir" ]; then
            		# Calculate the hash for the directory
            		directory_hash=$(find "$AWS_LAMBDA_DIR/$dir" -type f -exec md5sum {} \; | md5sum | awk '{print $1}')


            		# Store the hash in the associative array
            		directory_hashes_new["$dir"]=$directory_hash
        	else
            		echo "Directory $dir does not exist"
        	fi
    	done

    	# Construct the new JSON data manually
    	json_data_new="{\"directory_hashes\": {"
    	for dir in "${!directory_hashes_new[@]}"; do
        	json_data_new+="\"$dir\":\"${directory_hashes_new[$dir]}\","
    	done
    	# Remove the trailing comma if there are entries
    	if [ "${#directory_hashes_new[@]}" -gt 0 ]; then
        	json_data_new=${json_data_new%,}
    	fi
    	json_data_new+="}}"

    	# Write new JSON data to the file
    	echo "$json_data_new" > "$HASHES_JSON_FILE"
    	echo "New hashes saved to $HASHES_JSON_FILE"

    	# Check if the old hashes file exists
    	if [ -e "$OLD_HASHES_JSON_FILE" ]; then
        	# Compare new hashes with old hashes
        	diff_result=$(diff -u "$OLD_HASHES_JSON_FILE" "$HASHES_JSON_FILE")

    	else
        	echo "Old hashes file $OLD_HASHES_JSON_FILE not found. Unable to perform comparison."
    	fi

else
    echo "$AWS_LAMBDA_DIR directory does not exist"
fi




}


#####################################################################################################################
#                             Find new or deleted Lambda functions                                                  #
#####################################################################################################################

find_NewFolder() {
# Read JSON data from files
json1=$(cat "$file_path")
json2=$(cat "$old_file_path")

# Extract keys from each JSON
keys_json1=$(echo "$json1" | jq -r '.directory_hashes | keys_unsorted[]')
keys_json2=$(echo "$json2" | jq -r '.directory_hashes | keys_unsorted[]')

# Find keys unique to each JSON file
unique_keys_json1=$(comm -23 <(echo "$keys_json1" | sort) <(echo "$keys_json2" | sort))
unique_keys_json2=$(comm -13 <(echo "$keys_json1" | sort) <(echo "$keys_json2" | sort))

# Print the unique keys for each JSON file
echo "Unique Keys in $file_path:"
#echo "$unique_keys_json1"

	array_of_new_folders=($unique_keys_json1)

	for item in "${array_of_new_folders[@]}"; do

		echo "$LAMBDA_DIR_PATH$item"
		echo "new folders are: $item"
		make_lambda_zip "$item"
	done

	echo "Unique Keys in $old_file_path:"
	echo "$unique_keys_json2"

	array_of_old_folders=($unique_keys_json2)

	for old_item in "${array_of_old_folders[@]}"; do

		echo "$LAMBDA_DIR_PATH$old_item"
		echo "old folders are: $old_item"
		delete_lambda "$old_item"
	done


}
################################################################################################################
#                                       Update Lambda Function                                                 #
################################################################################################################
update_lambda_zip() {
   folder_name=$1
   full_path="$LAMBDA_DIR_PATH$folder_name"
   echo "the make_lambda_zip full_path: $full_path"
   cd "$full_path"
   npm install
   timestamp=$(date +"%Y%m%d%H%M%S")
   zip -r "../../../${folder_name}_${timestamp}.zip" .

   lambda_config_json=$(cat config.json)

    # Extract values using jq
    memory=$(echo "$lambda_config_json" | jq -r '.memory')
    timeout=$(echo "$lambda_config_json" | jq -r '.timeout')
    concurrency=$(echo "$lambda_config_json" | jq -r '.cocurrency')

    # Display the values 
   cd "$WORK_DIR"
   ### copy zip to s3 
   echo "$(pwd)"
    echo "Memory: $memory"
    echo "Timeout: $timeout"
    echo "Concurrency: $concurrency"
    echo "$lambda_bucketname"
    echo "${folder_name}_${timestamp}.zip"
    echo "$TB_APIURL_var"
    echo "$TBAPISYSTEMACCESSKEY_var"
    lambda_zip_package="${folder_name}_${timestamp}.zip"
    aws s3 cp $lambda_zip_package s3://$lambda_bucketname/lambda/$folder_name/
    aws s3 cp s3://$lambda_bucketname/cloudformation/lambda/Lambda_Function_template.yaml .
    sed -i "s/zipfilename.zip/$lambda_zip_package/g" Lambda_Function_template.yaml
    sed -i "s/foldername/$folder_name/g" Lambda_Function_template.yaml
    sed -i "s/tblambdabucket/$lambda_bucketname/g" Lambda_Function_template.yaml
    cat Lambda_Function_template.yaml

### following is for test just to upate the stack

   aws cloudformation update-stack \
    --stack-name "${folder_name}" \
    --template-body file://Lambda_Function_template.yaml \
    --parameters ParameterKey=TBAPIURL,ParameterValue="$TB_APIURL_var" \
                 ParameterKey=TBAPISYSTEMACCESSKEY,ParameterValue="$TBAPISYSTEMACCESSKEY_var" \
                 ParameterKey=FunctionName,ParameterValue="$folder_name" \
                 ParameterKey=FunctionMemory,ParameterValue="$memory" \
                 ParameterKey=FunctionTimeout,ParameterValue="$timeout" \
                 ParameterKey=FunctionSourceCodeBucket,ParameterValue="$lambda_bucketname"

    aws s3 rm s3://$lambda_bucketname/lambda/$folder_name/ --recursive --exclude "$lambda_zip_package"


}

##############################################################################################################################
#                                                 Create Lambda Functions                                                    #
##############################################################################################################################
make_lambda_zip() {
   folder_name=$1
   full_path="$LAMBDA_DIR_PATH$folder_name"
   echo "the make_lambda_zip full_path: $full_path"
   cd "$full_path"
   npm install
   timestamp=$(date +"%Y%m%d%H%M%S")
   zip -r "../../../${folder_name}_${timestamp}.zip" .

   lambda_config_json=$(cat config.json)

    # Extract values using jq
    memory=$(echo "$lambda_config_json" | jq -r '.memory')
    timeout=$(echo "$lambda_config_json" | jq -r '.timeout')
    concurrency=$(echo "$lambda_config_json" | jq -r '.cocurrency')

    # Display the values
   cd "$WORK_DIR"
   ### copy zip to s3
   echo "$(pwd)"
    echo "Memory: $memory"
    echo "Timeout: $timeout"
    echo "Concurrency: $concurrency"
    echo "$lambda_bucketname"
    echo "${folder_name}_${timestamp}.zip"
    echo "$TB_APIURL_var"
    echo "$TBAPISYSTEMACCESSKEY_var"
    lambda_zip_package="${folder_name}_${timestamp}.zip"
    aws s3 cp $lambda_zip_package s3://$lambda_bucketname/lambda/$folder_name/
    aws s3 cp s3://$lambda_bucketname/cloudformation/lambda/Lambda_Function_template.yaml .
    sed -i "s/zipfilename.zip/$lambda_zip_package/g" Lambda_Function_template.yaml
    sed -i "s/foldername/$folder_name/g" Lambda_Function_template.yaml
    sed -i "s/tblambdabucket/$lambda_bucketname/g" Lambda_Function_template.yaml
    cat Lambda_Function_template.yaml
### Uncomment following
    aws cloudformation deploy \
        --stack-name "${folder_name}" \
        --template-file Lambda_Function_template.yaml \
        --parameter-overrides \
          TBAPIURL="$TB_APIURL_var" \
          TBAPISYSTEMACCESSKEY="$TBAPISYSTEMACCESSKEY_var" \
          FunctionName="$folder_name" \
          FunctionMemory="$memory" \
          FunctionTimeout="$timeout" \
         FunctionSourceCodeBucket="$lambda_bucketname"
### following is for test just to upate the stack
      aws s3 rm s3://$lambda_bucketname/lambda/$folder_name/ --recursive --exclude "$lambda_zip_package"
}

#################################################################################################################################
#                                                 Delete Lambda Function                                                        #
#################################################################################################################################

delete_lambda() {
	folder_name=$1

	echo "Deleting cloudformation stack for lambda: $folder_name"
	aws cloudformation delete-stack --stack-name "${folder_name}"


}


################################################################################################################
#                                             MAIN BODY                                                        #
################################################################################################################
create_hashes
# Read directory_hashes from file
directory_hashes=$(jq -c '.directory_hashes' "$file_path")
old_directory_hashes=$(jq -c '.directory_hashes' "$old_file_path")
# Extract keys and values, excluding the initial directory_hashes
remaining_pairs=$(jq -r 'to_entries[0:] | .[] | "\(.key):\"\(.value)\""' <<< "$directory_hashes")
old_remaining_pairs=$(jq -r 'to_entries[0:] | .[] | "\(.key):\"\(.value)\""' <<< "$old_directory_hashes")


array_of_pairs=($remaining_pairs)
old_array_of_pairs=($old_remaining_pairs)
# Print the array elements
for pair in "${array_of_pairs[@]}"; do
    read -r key value <<< "$(echo "$pair" | awk -F':' '{print $1, $2}')"

    for old_pair in "${old_array_of_pairs[@]}"; do
       if [[ "$old_pair" == *"$key:"* ]]; then
          if [ "$pair" != "$old_pair" ]; then
            echo "foldername: $key"
            echo "current hashes: $pair"
            echo "old hashes: $old_pair"
            update_lambda_zip "$key" 
          fi
       fi

    done
done

find_NewFolder
