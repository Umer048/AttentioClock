# Git and GitHub setup for AttentioClock

## One-time setup (Android Studio)

1. Create a GitHub account at https://github.com if you do not already have one.
2. On GitHub, click **New repository**.
3. Repository name: `AttentioClock`
4. Choose **Private** (recommended while this is a university project).
5. Do not add a README, `.gitignore`, or license on GitHub because this project already has local files.
6. Create the repository. Keep the page open; it shows the repository URL.

## Connect the existing Android Studio project

1. Open `E:\AttentioClock_Rebuild` in Android Studio (the folder containing `pubspec.yaml`).
2. If Git is not installed, install Git for Windows from https://git-scm.com/download/win, then restart Android Studio.
3. In Android Studio choose **VCS → Enable Version Control Integration…** (in newer versions it may be **Git → Enable Version Control Integration…**).
4. Select **Git**, then OK. This creates the local Git repository.
5. Open **File → Settings → Version Control → GitHub** (on macOS: Android Studio → Settings/Preferences). Sign in using **Log In via GitHub**. If that menu is missing, use **Settings → Plugins** and make sure the GitHub plugin is enabled.
6. Choose **Git → Manage Remotes…** (or **VCS → Git → Remotes…**), press **+**, name it `origin`, and paste the HTTPS URL from your new GitHub repository, e.g. `https://github.com/YOUR-USERNAME/AttentioClock.git`. Press OK.
7. Open **View → Tool Windows → Commit**. Review the files. Make sure `.gitignore` is included and `android/local.properties`, `.dart_tool`, `build`, and secrets are NOT included.
8. Enter commit message: `Initial commit - AttentioClock project`.
9. Click **Commit and Push**. If you only see Commit, click the arrow/menu beside it and choose **Commit and Push**. Confirm the remote and push.

## Every work session (regular workflow)

1. Before editing, open the project and pull latest changes: **Git → Pull**.
2. Make and test a small change.
3. Run `flutter analyze`; then run/test on the emulator or phone.
4. Open the Commit tool window, review changed files, and write a meaningful message, for example:
   - `Improve maroon alarm session UI`
   - `Fix passage library loading`
   - `Add alarm sound preview`
5. Click **Commit and Push**.
6. Confirm the push completed. A local commit alone is NOT on GitHub.

## Useful Git rules

- Commit after each working feature or stable fix, not every keystroke.
- Do not commit `android/local.properties`, signing passwords, API keys, or private credentials.
- Never force-push for this beginner workflow.
- If Android Studio asks to set a Git username/email, use your own name and GitHub email.
- Git is version control; GitHub is the online copy/backup. Android Studio is the interface used to operate Git.

## If Android Studio menus differ

Open **View → Tool Windows → Terminal** and run these commands from the project root:

```powershell
git --version
git init
git add .
git status
git commit -m "Initial commit - AttentioClock project"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/AttentioClock.git
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username and use the exact repository URL GitHub gives you. If `git remote add origin` says `origin already exists`, use `git remote set-url origin https://github.com/YOUR-USERNAME/AttentioClock.git`.

For later updates:

```powershell
git add .
git status
git commit -m "Describe the change"
git push
```
