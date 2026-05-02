#!/bin/bash
# ======================================
# 🧭 Developer Journey Common Aliases
# ======================================

# --- Root ---
alias cddev='cd ~/dev-journey'
alias cdc='cd ~/dev-journey && nvim'

# --- Logs ---
alias cdlogs='cd ~/dev-journey/00-logs'
alias cddaily='cd ~/dev-journey/00-logs/daily'
alias cdweekly='cd ~/dev-journey/00-logs/weekly'
alias cdmonthly='cd ~/dev-journey/00-logs/monthly'

# --- MERN: General ---
alias cdmern='cd ~/dev-journey/01-mern-typescript'
alias cdmernnotes='cd ~/dev-journey/01-mern-typescript/notes'
alias cdmernprac='cd ~/dev-journey/01-mern-typescript/practice'
alias cdmernproj='cd ~/dev-journey/01-mern-typescript/projects'

# --- JavaScript ---
alias cdjsnotes='cd ~/dev-journey/01-mern-typescript/notes/js-notes'
alias cdjsprac='cd ~/dev-journey/01-mern-typescript/practice/javascript'

# --- CSS (Flattened) ---
alias cdcssnotes='cd ~/dev-journey/01-mern-typescript/notes/css-notes'
alias cdcssprac='cd ~/dev-journey/01-mern-typescript/practice/css'

# --- HTML (Flattened) ---
alias cdhtmlnotes='cd ~/dev-journey/01-mern-typescript/notes/html-notes'
alias cdhtmlprac='cd ~/dev-journey/01-mern-typescript/practice/html'

# --- Node.js ---
alias cdnodenotes='cd ~/dev-journey/01-mern-typescript/notes/node-notes'
alias cdnodeprac='cd ~/dev-journey/01-mern-typescript/practice/node'

# --- Express.js ---
alias cdexpressnotes='cd ~/dev-journey/01-mern-typescript/notes/express-notes'
alias cdexpressprac='cd ~/dev-journey/01-mern-typescript/practice/express'

# --- MongoDB ---
alias cdmongonotes='cd ~/dev-journey/01-mern-typescript/notes/mongo-notes'
alias cdmongoprac='cd ~/dev-journey/01-mern-typescript/practice/mongodb'

# --- React ---
alias cdreactnotes='cd ~/dev-journey/01-mern-typescript/notes/react-notes'
alias cdreactprac='cd ~/dev-journey/01-mern-typescript/practice/react'

# --- MERN Projects ---
alias cdyelp='cd ~/dev-journey/01-mern-typescript/projects/yelpcamp'
alias cdmuitodo='cd ~/dev-journey/01-mern-typescript/projects/mui-todo'

# --- Java + DSA ---
alias cdjava='cd ~/dev-journey/02-java-dsa/java'
alias cdjavanotes='cd ~/dev-journey/02-java-dsa/java/notes'
alias cdjavaprac='cd ~/dev-journey/02-java-dsa/java/practice'

alias cddsa='cd ~/dev-journey/02-java-dsa/dsa'
alias cdsanotes='cd ~/dev-journey/02-java-dsa/dsa/notes'
alias cdsaprac='cd ~/dev-journey/02-java-dsa/dsa/practice'

# --- Spring Boot ---
alias cdboot='cd ~/dev-journey/03-spring-boot'
alias cdbootnotes='cd ~/dev-journey/03-spring-boot/notes'
alias cdbootprac='cd ~/dev-journey/03-spring-boot/practice'
alias cdbootproj='cd ~/dev-journey/03-spring-boot/projects'

# --- Resources & Scripts ---
alias cdres='cd ~/dev-journey/04-resources'
alias cdscripts='cd ~/dev-journey/05-scripts'

# --- Utilities ---
alias log='CMD_NAME=log bash ~/dev-journey/05-scripts/log-manager.sh'
alias gst-all='~/dev-journey/05-scripts/gitstatus-all.sh'
alias cleanmodules='~/dev-journey/05-scripts/clean-modules.sh'

# --- Gitignore Templates ---
alias gi-mern='cp -i ~/dev-journey/05-scripts/gitignore-templates/mern.gitignore .gitignore'
alias gi-boot='cp -i ~/dev-journey/05-scripts/gitignore-templates/springboot.gitignore .gitignore'

# --- Windows Tools (WSL) ---
sumatra() {
  "/mnt/c/Users/ARYAN SHINDE/AppData/Local/SumatraPDF/SumatraPDF.exe" "$(wslpath -w "$1")"
}
