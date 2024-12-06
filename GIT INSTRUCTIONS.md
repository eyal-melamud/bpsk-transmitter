# BPSK moudels


## GIT ##
### git commands ###
#### `git clone https://github.cs.huji.ac.il/eyal-melamud/IAI_Final_Project.git new_folder`
Creates the folder `new_folder` and clones into it the repo from the *remote git repo*.
If `new_folder` is omitted.
#### `git pull`
Updates you *local git repo* with new `commit`s from the *remote git repo*.
#### `git branch`
Lists all the existing barnches and mark the one you are currently on.
Each branch is splitting out a different branch at a certain `commit` and will
usually merge back into the same branch.
#### `git checkout other-branch`
Switches to a different branch (here one named `other-branch`).
All the files will change according to thier status in the other branch.
To create a new branch which split out the current one, add `-b` before the name of the new branch.
#### `git status`
Show the current status of files (which files were added/edited/removed).
#### `git add path`
Adds the changes to the file `path` to the list of changes for the next `commit`.
Use `git add -A` to add all the changes.
#### `git commit -m "commit message"`
Creats a new commit of all the changes that were `add`ed.
It is like saving the status on your *local git repository*.
You MUST add that `-m "message"`, or else you will open vim.
#### `git push`
Updates the *remote git repo* with you new local commits.
If the branch is new, the first push should also update the *remote git repo* about the new branch.
To do so, use `git push -u origin new-branch-name`.
