git config --global user.email ${GIT_USER_NAME}@github.com
git config --global user.name ${GIT_USER_NAME}
if [ -n "${MY_PROXY}" ]; then
    git config  http.https://github.com.proxy ${MY_PROXY}
    export HTTPS_PROXY=${MY_PROXY}
fi