## Copyright (c) 2012 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.

""" Add a project to a worktree

"""

import os

import qisrc
import qibuild


def configure_parser(parser):
    """ Configure parser for this action """
    qibuild.parsers.worktree_parser(parser)
    parser.add_argument("src", metavar="PATH",
        help="Path to the project sources")

def do(args):
    """Main entry point"""
    src = args.src
    src = qibuild.sh.to_native_path(src)
    if not os.path.exists(src):
        raise Exception("%s does not exists" % src)
    worktree = qisrc.open_worktree(args.worktree)
    worktree.add_project(src)
