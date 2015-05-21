#!/bin/bash -e

for unittest in unittest/test-missing-backup-in-rotation.sh unittest/test-rotate-monthly.sh unittest/test-rotation.sh unittest/test-current-not-new-enough.sh unittest/test-missing-schedule-in-rotation.sh unittest/test-rotate-weekly.sh unittest/test-current-too-old.sh unittest/test-rotate-daily.sh unittest/test-rotate-yearly-leap-year.sh unittest/test-ignore-other-files.sh unittest/test-rotate-monthly-leap-year.sh unittest/test-rotate-yearly.sh; do
    ./$unittest
    if ! ./remember-rotate.sh; then
        # suppress execution errors in the rotate script
        :
    fi
done
