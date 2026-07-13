# Uploading This Project to GitHub Using the Website

1. Sign in to GitHub.
2. Select the **+** icon in the upper-right corner.
3. Select **New repository**.
4. Enter `terraform-aws-vprofile-mysql` as the repository name.
5. Paste the repository description from `docs/GITHUB_POST.md`.
6. Choose **Public** or **Private**.
7. Do not select **Add a README file**, **Add .gitignore**, or **Choose a license**, because all three are already included in the project.
8. Select **Create repository**.
9. On the empty repository page, select **uploading an existing file**.
10. Open the extracted project folder on your computer.
11. Select every file and folder inside the project folder, not the outer folder itself.
12. Drag the selected items into the GitHub upload area.
13. Confirm that `README.md`, the `.tf` files, `scripts`, `database`, `docs`, `.gitignore`, and `LICENSE` appear in the upload list.
14. In **Commit changes**, enter `Initial Terraform AWS VProfile project`.
15. Select **Commit changes**.
16. Open the repository home page and confirm that the README renders correctly.
17. In the **About** section, select the gear icon.
18. Add the repository description and the topics from `docs/GITHUB_POST.md`.
19. Enable **Releases**, **Packages**, and **Deployments** only when needed.
20. Confirm that `terraform.tfvars`, state files, plan files, and PEM keys were not uploaded.
