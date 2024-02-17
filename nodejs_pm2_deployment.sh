#!/bin/bash
# Setting the absolute path to repository
PATH_TO_ROOT_DIR=/var/www/Dev_QA/tbv1_admin_frontend/
PATH_TO_ADMIN_FE_V1=/var/www/Dev_QA/tbv1_admin_frontend/admin_frontend
PATH_TO_CRONLOGS=/var/www/Dev_QA/tbv1_admin_frontend/admin_frontend-deployment.log
PATH_TO_GITKEY=$(cat /var/www/Dev_QA/tbv1_admin_frontend/git_readonly_key/admin_frontend)
WORKDIR=/var/www/admin_frontend_dev/
ADMIN_FE_DIR=admin_frontend_dev/

cd $PATH_TO_ROOT_DIR
git clone $PATH_TO_GITKEY


# Resetting the files ownership
# GIT Security Policy for safe repository ownership
git config --global --add safe.directory $PATH_TO_ADMIN_FE_V1

# Output for writing logs
# 1. Cleaning any changes made by system user
# 2. Checking out to `qa` branch
# 3. Pulling `develop` branch
# 4. Pushing the code

output=$(
  # BEGIN: Frontend
  git -C $PATH_TO_ADMIN_FE_V1 clean -df &&
  git -C $PATH_TO_ADMIN_FE_V1 checkout master &&
  #git -C $PATH_TO_ADMIN_FE_V1 branch -D develop &&
  git -C $PATH_TO_ADMIN_FE_V1 fetch &&
  git -C $PATH_TO_ADMIN_FE_V1 checkout develop &&
  git -C $PATH_TO_ADMIN_FE_V1 pull origin develop
)
echo "$output"
echo [`date`]: $output >> $PATH_TO_CRONLOGS
cp .env $PATH_TO_ADMIN_FE_V1

#rm -rf $WORKDIR

#mv $PATH_TO_ADMIN_FE_V1 $WORKDIR

cd $PATH_TO_ADMIN_FE_V1

sed -i 's/3002/3004/' package.json


export PATH="/root/.nvm/versions/node/v18.13.0/bin/:$PATH"


npm install --legacy-peer-deps && npm run build
# Check if the process already exists

rm -rf $WORKDIR
mv $PATH_TO_ADMIN_FE_V1 $WORKDIR

cd $WORKDIR

if pm2 describe adminFrontendDev > /dev/null 2>&1; then
    echo "Process 'adminFrontendDev' already exists. just restarting it"
    pm2 restart adminFrontendDev
  else pm2 start npm --name "adminFrontendDev" -- run dev
fi