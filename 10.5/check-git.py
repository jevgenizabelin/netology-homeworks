#!/usr/bin/env python3

import os
import sentry_sdk


sentry_sdk.init(
    "https://74991ac7df084fbcaa9e38bdcf07d4ea@o1075405.ingest.sentry.io/6076030",
    traces_sample_rate=1.0
)

try:
   bash_command = ["cd /root/git-repos/my_own_collectio/", "git status"]
except Exception as e:
   sentry_sdk.capture_exception(error=e)

result_os = os.popen(' && '.join(bash_command)).read()
is_change = False
for result in result_os.split('\n'):
    if result.find('modified') != -1:
        prepare_result = result.replace('\tmodified:   ', '/root/git-repos/my_own_collection/')
        print(prepare_result)
