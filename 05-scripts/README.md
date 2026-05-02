# 📘 **`05-scripts/README.md` — Developer Journey Scripts**

### 🧭 Overview

This folder contains all automation scripts and command shortcuts used throughout the **Dev Journey** roadmap.
Each script is built for practicality, simplicity, and long-term reusability — designed to make your workflow consistent across all three phases:

| Phase       | Focus                |
| ----------- | -------------------- |
| **Phase 1** | MERN + TypeScript    |
| **Phase 2** | Java + DSA           |
| **Phase 3** | Spring Boot + Docker |

---

## ⚙️ **1️⃣ log-manager.sh**

📍 **Path:** `~/dev-journey/05-scripts/log-manager.sh`
🧠 **Purpose:** Manage daily, weekly, and monthly developer logs using a **chronological (Time > Topic)** philosophy.

### 🔹 Features

* **Chronological Structure:** Forces a flat, date-based file system (no nested topic folders).
* **Smart Appending:**
  * `log daily` → Opens today's log.
  * `log daily "React"` → Appends a **"## 🔵 React"** header to today's log (doesn't overwrite previous notes).
* **Auto-linking (Wiki Style):**
  * Creating a **Daily** log automatically links it into the **Weekly** log.
  * Creating a **Weekly** log automatically links it into the **Monthly** log.
* **Dashboard:** Displays statistics (Daily/Weekly/Monthly) and recent activity at a glance.
* **`--clean` mode:** Safely deletes empty (0-byte) log files.
* **Editor Integration:** Opens logs directly in **VS Code**.

### 🔹 Example Usage

```bash
log daily              # Open today's log
log daily "React"      # Add a new session/header to today's log
log weekly             # Open this week's review
log monthly            # Open this month's retro
log --clean            # Remove empty files
```

### 🔹 Sample Output

```
=============================================
📔  Dev Journey Dashboard
=============================================
📅 Today:  Monday, 01 December 2025
📁 Root:   /home/aryan/dev-journey/00-logs

📊 Statistics:
  • Daily Logs:   1
  • Weekly Logs:  1
  • Monthly Logs: 1

🕓 Last 3 Daily Logs:
  • 2025-12-01.md

💡 Usage:
  log daily              (Open today's log)
  log daily "Topic"      (Append 'Topic' header)
  log weekly             (Weekly review)
  log monthly            (Monthly retro)
  log --clean            (Delete empty files)
=============================================
```

---

## 🧩 **2️⃣ gitstatus-all.sh**

📍 **Path:** `~/dev-journey/05-scripts/gitstatus-all.sh`
🧠 **Purpose:** Scan every Git repository inside `~/dev-journey` and display branch status, uncommitted changes, and sync info.

### 🔹 Features

* Recursively detects all `.git` repos
* Shows:
  * 📂 Repository path
  * 🌿 Current branch name
  * ⚠️ Uncommitted changes
  * ⬆️ Commits ahead of remote
  * ⬇️ Commits behind remote
  * ✅ Clean repos clearly marked
* Uses color-coded output for readability
* Fast and safe — skips non-git folders automatically

### 🔹 Example Usage

```bash
gst-all
```

### 🔹 Sample Output

```
🔍 Checking Git repos inside: /home/aryan/dev-journey
--------------------------------------------------
📁 Repository: /home/aryan/dev-journey/01-mern-typescript/projects/blog-app
   Branch: main
   ✅ Clean working directory

📁 Repository: /home/aryan/dev-journey/03-spring-boot/projects/api-service
   Branch: dev
   ⚠️  Uncommitted changes:
    M src/main/java/com/example/App.java
   ⬆️  2 commit(s) ahead of remote
--------------------------------------------------
✨ Done scanning all repositories.
```

---

## ⚡ **3️⃣ common-aliases.sh**

📍 **Path:** `~/dev-journey/05-scripts/common-aliases.sh`
🧠 **Purpose:** Provide fast command shortcuts for navigation, logging, and project setup.

### 🔹 Highlights

| Category        | Alias                                                                   | Action                                   |
| --------------- | ----------------------------------------------------------------------- | ---------------------------------------- |
| **Logs**        | `log`                                                                   | Opens the log manager                    |
|                 | `cdlogs`, `cddaily`, `cdweekly`, `cdmonthly`                            | Navigate between log folders             |
| **MERN Root**   | `cdmern`, `cdmernnotes`, `cdmernprac`, `cdmernproj`                     | Quick access to main MERN directories    |
| **JavaScript**  | `cdjsnotes`, `cdjsprac`                                                 | JS Notes & Practice Root (`01-basics`..) |
| **CSS**         | `cdcssnotes`, `cdcssprac`                                               | CSS Notes & Practice Root (`01-core`..)  |
| **HTML**        | `cdhtmlnotes`, `cdhtmlprac`                                             | HTML Notes & Practice Root               |
| **Java + DSA**  | `cdjava`, `cdjavanotes`, `cdjavaprac`, `cddsa`, `cdsanotes`, `cdsaprac` | Java/DSA quick navigation                |
| **Spring Boot** | `cdboot`, `cdbootnotes`, `cdbootprac`, `cdbootproj`                     | Spring Boot navigation                   |
| **Resources**   | `cdres`, `cdscripts`                                                    | Jump to resource/script folders          |
| **Utilities**   | `gst-all`                                                               | Check git status of all repos            |
|                 | `cdc`                                                                   | Open entire `dev-journey` in VS Code     |
| **Gitignore**   | `gi-mern`, `gi-boot`                                                    | Copy ready-to-use `.gitignore` templates |

### 🔹 Setup

Add the following line to `~/.bashrc` or `~/.zshrc` to make aliases permanent:

```bash
source ~/dev-journey/05-scripts/common-aliases.sh
```

Then reload:

```bash
source ~/.bashrc
```

---

## 🧰 **Gitignore Templates**

📍 **Path:** `~/dev-journey/05-scripts/gitignore-templates/`
✅ Ready-to-use, production-accurate `.gitignore` files for:

* `mern.gitignore`
* `springboot.gitignore`

Usage:

```bash
gi-mern
# or
gi-boot
```

Each copies the right template into your current project folder (with `-i` safety prompt).

---

## 🧾 **Summary**

| Script                | Role                 | Status  |
| --------------------- | -------------------- | ------- |
| 🧭 `log-manager.sh`    | Developer journaling | ✅ Final |
| 🧩 `gitstatus-all.sh`  | Repo dashboard       | ✅ Final |
| ⚙️ `common-aliases.sh` | CLI shortcuts        | ✅ Final |
| 🗂️ Gitignore templates | Project setup        | ✅ Final |

Your toolkit is **complete, clean, and future-ready**.
Every command helps you **think less about management** and **focus more on building**.

---

### 💡 Author

**Aryan**
*Dev Journey 2025 — MERN + Java + Spring Boot + Docker Roadmap*