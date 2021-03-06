## Copyright (c) 2012 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.

"""This module implements the Gentoo binary packages class.

This module optionally does not depends on portage:
http://www.gentoo.org/proj/en/portage/index.xml

"""

import os
import re
import qibuild
from qitoolchain.binary_package.core import BinaryPackage

class GentooPackage(BinaryPackage):
    """ Gentoo binary package endpoint (does not use ``portage``).

    """
    # regex copied from portage.versions source
    _PN = r'(?P<pn>[\w+][\w+-]*?(?P<pn_inval>-(cvs\.)?(\d+)((\.\d+)*)([a-z]?)((_(pre|p|beta|alpha|rc)\d*)*)(-r(\d+))?)?)'
    _PV = r'(?P<ver>(cvs\.)?(\d+)((\.\d+)*)([a-z]?)((_(pre|p|beta|alpha|rc)\d*)*))'
    _PR = r'(-r(?P<rev>\d+))?'
    _PF = r'^' + _PN + '-' + _PV + _PR + '$'

    _RE_PF = re.compile(_PF)

    def __init__(self, package_path):
        BinaryPackage.__init__(self, 'gentoo', package_path)

    def get_metadata(self):
        """ Guess the metadata from the package file name and store it in the
        instance.

        :return: the metadata dictionary

        """
        if self.metadata is not None:
            return self.metadata
        pkg_pf = os.path.basename(self.path)[:-5]
        match = self._RE_PF.search(pkg_pf)
        pkg_metadata = {
            'name'         : match.groupdict()['pn'],
            'version'      : match.groupdict()['ver'],
            'revision'     : match.groupdict()['rev'],
            }
        self.metadata = pkg_metadata
        return self.metadata

    def extract(self, dest_dir):
        """ Extract the Gentoo binary package content, without the metadata.

        :param dest_dir: the extraction directory

        :return: the root directory of the extracted content

        """
        if not os.path.exists(dest_dir):
            mess = 'No such file or directory: %s' % dest_dir
            raise Exception(mess)
        root_dir =  qibuild.archive.extract(self.path, dest_dir, algo="bzip2", quiet=True)
        return root_dir
