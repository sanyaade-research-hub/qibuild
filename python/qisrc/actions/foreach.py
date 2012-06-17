## Copyright (c) 2012 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.

"""Run the same command on each source project.
Example:
    qisrc foreach -- git reset --hard origin/mytag

Use -- to seprate qisrc arguments from the arguments of the command.
"""

import sys

import qisrc
import qibuild
from qibuild import ui

def configure_parser(parser):
    """Configure parser for this action """
    qibuild.parsers.worktree_parser(parser)
    parser.add_argument("command", metavar="COMMAND", nargs="+")
    parser.add_argument("--ignore-errors", "--continue",
        action="store_true", help="continue on error")

def do(args):
    """Main entry point"""
    qiwt = qisrc.open_worktree(args.worktree)
    errors = list()
    ui.info(ui.green, "Running `%s` on every project" % " ".join(args.command))
    for project in qiwt.git_projects:
        command = args.command[:]
        ui.info(ui.blue, "::", ui.reset, ui.bold, project.src)
        try:
            qibuild.command.call(command, cwd=project.path)
        except qibuild.command.CommandFailedException:
            if args.ignore_errors:
                errors.append(project)
                continue
            else:
                raise
    if not errors:
        return
    ui.error("Command failed on the following projects:")
    for project in errors:
        ui.info(ui.bold, " - ", project.src)

