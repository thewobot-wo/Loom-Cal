Use git clone <repository-URL> to clone a GitHub repository to your local machine. 1 2 3
Steps:
	1.	Go to the repository's main page on GitHub and click the Code button (green). 1 4	2.	Copy the HTTPS URL (e.g., https://github.com/YOUR-USERNAME/YOUR-REPOSITORY). 1	3.	Open Terminal or Git Bash, navigate to your desired directory. 1	4.	Run:

git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY
This creates a local folder with the repo's contents, history, and branches. 1 5 3
Options:
	•	Clone a specific branch: git clone --branch <branch-name> <URL> 5	•	Clone without working directory: git clone --bare <URL> 5 2	•	Using GitHub CLI: gh repo clone <URL> 1
The clone includes a remote named "origin" for future pushes/pulls. 5

-------

After clearing context, run:
/paul:unify .paul/phases/06-ai-daily-planning/06-02-PLAN.md                                                    

git clone [<repository-URL>](https://github.com/thewobot-wo/Loom-Cal.git)