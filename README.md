# My Dev Machine Setup

## Intro

A set of very opinionated scripts for setting up a new dev machine. The idea here is to quickly do an initial setup including installing apps, installing NPM packages, and configurations for using Github and AWS. This is very much specific to my usecase. It does not include everything a developer might need and so might not be the base setup you might want. Before using review the scripts and update the apps, NPM packages, and the themes as needed. The apps and NPM packages are listed in separate files for easy modification.

## Structure

- `/data` - list of NPM packages and theme files are stored here.
- `/Linux` - nothing yet, this is a "to do" item.
- `/MacOS` - list of apps to install for MacOS and the scripts to run individually.
- `/Windows` - this has some **_untested_** scripts.

## Requirements

- Pick your OS (currently this only works for MacOS).
- Review the `README` for your OS.
- Familiarity with using your terminal and running scripts.
- If setting up git for use with Github, log into your github account and keep handy the name and email address to use for your global git configuration.
- If setting up AWS CLI, have your AWS access key and secret key from your AWS user account in the IAM dashboard.

## Installation and Usage

1. Download the zip, clone this repo, or just copy and paste the scripts and associated file structure.
2. Open terminal on your machine and `cd` to the directory where this is on your system.
3. **Create `config.sh` in the project root** - This file is required and contains all configurable settings. See `config.sh` for all available options.
4. `cd` into `/data/packages` and review the list of NPM packages, making any necessary updates.
5. `cd` into `/data/themes` and review the theme files and make any updates needed.
6. `cd` into the directory specific to your platform (currently this has only been tested on MacOS).
7. Update the list of apps in `apps.txt` if needed.
8. From the terminal run the appropriate scripts.

## To Do

- [ ] Add [AWS-CDK](https://github.com/aws/aws-cdk?tab=readme-ov-file#getting-started).
- [ ] Add theme files for other terminal apps (e.g. Warp)
- [ ] Test scripts for setting up Windows.
- [ ] Add scripts for setting up Linux after determining Linux versions to support.
