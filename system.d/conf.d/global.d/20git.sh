# script with functions to handle a git archive

global initSourceGit

initSourceGit() {
# initialise a git archive for a project
    logMessage INFO "Initialising git archive."
    mkdir -p $PROJECT_DIR/git.d || error 3 "coudn't make git directory."
    cd $PROJECT_DIR/git.d
    git clone "$GIT_URL" || error 3 "error in git clone."
}
