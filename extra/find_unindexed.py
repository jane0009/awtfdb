#!/usr/bin/env python3
#
# find out which files from a folder are not indexed
#
# use: find_unindexed.py path/to/folder

import sys
import sqlite3
import logging
from pathlib import Path


log = logging.getLogger(__name__)


def main():
    logging.basicConfig(level=logging.INFO)
    path = Path.home() / "awtf.db"
    db = sqlite3.connect(f"file:{str(path)}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row

    folder_to_check = Path(sys.argv[1]).resolve()
    files_in_folder = set(folder_to_check.glob("**/*"))

    log.info("%d files in folder", len(files_in_folder))

    cur = db.cursor()
    res = cur.execute(
        """
        select local_path
        from files
        where local_path LIKE ? || '%'
        """,
        (str(folder_to_check),),
    )
    indexed_files = set()
    for row in res:
        indexed_files.add(Path(row["local_path"]))

    unindexed_files = files_in_folder - indexed_files
    for path in unindexed_files:
        print(path)

    log.info("%d files in folder", len(files_in_folder))
    log.info("%d files indexed for folder", len(indexed_files))
    log.info("path: %s", folder_to_check)

    print(len(unindexed_files), "unindexed files")


if __name__ == "__main__":
    sys.exit(main())