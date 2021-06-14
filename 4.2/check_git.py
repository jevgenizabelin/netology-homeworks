#!/usr/bin/env python3

import os, sys

repo_dir = sys.argv[1]
bash_command = ["cd" + " " + repo_dir, "git status"]
result_os = os.popen(' && '.join(bash_command)).read()
for result in result_os.split('\n'):
    if os.path.exists(repo_dir + '.git') == False:
         print('This is not git repository')
    if result.find('modified') != -1:
       prepare_result = result.replace('\tmodified:   ', repo_dir + "/")
       print(prepare_result)

