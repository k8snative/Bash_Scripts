# Bash_Scripts
Contains bash scripts for different DevOps automation work

## deploy-lambda-resources.sh
This script is used in CI/CD pipeline, I have used it in AWS CodeBuild. 
In source code there is a folder named as **aws** and inside that there is another folder **lambda** 
so this script actually looking for **aws/lambda/** if that is present, it searches that any changes have been made to "lambda" folder (for changes it uses hashing technique). So if there will be any changes then there must be different hash.

## This script have four functions 
The main body from where the script starts
### Following are functions

**create_hashes**
This function downloads the old hashes, which were saved in hashes-old.json and uploaded to s3 bucket.
and it creates hashes for lambda folder and create the hashes.json file.
After this it get back to Main body and compares hashes.json and hashes-old.json and if there will be change in old and new hashes it call a function to modify lambda.

**update_lambda_zip**
when calling this function we pass an argument (folder name), function will cd to the folder directory and do the npm install (since it is nodejs lambda so we use npm intsall). and make a zip file with timestamp.
then we finds lambda configuration from config.json and loads all values into variables.
Then also downloads the sample cloudformation yaml file and replace bucketname and lambda.zip code.
Finally we call cloudformation update stack to update the lambda function.
At the end we deletes all previous lambda zip files from s3 and left the current one.

**find_NewFolder**
This function checks if any new lambda function has been added or deleted. so if a new lambda fuction code has been added into the repository it simply creates a new lambda function by calling a function make_lambda_zip or if a function has been removed from the repo it simply deletes the lambda function by calling a function delete_lambda

**make_lambda_zip**
when calling this function we pass an argument (folder name), function will cd to the folder directory and do the npm install (since it is nodejs lambda so we use npm intsall). and make a zip file with timestamp.
then we finds lambda configuration from config.json and loads all values into variables.
Then also downloads the sample cloudformation yaml file and replace bucketname and lambda.zip code.
Finally we call cloudformation create stack to update the lambda function.
At the end we deletes all previous lambda zip files from s3 and left the current one.

**delete_lambda**
This function is being called from find_NewFolder function. the work for this function is to delete the lambda function by calling cloudformation delete stack