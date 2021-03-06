## Copyright (c) 2012 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.

#! Testing
# ========
#
# This CMake module provides functions to interface gtest with ctest.
#
# .. seealso::
#
#    * :ref:`qibuild-ctest`
#


set(_TESTS_RESULTS_FOLDER "${CMAKE_CURRENT_BINARY_DIR}/test-results" CACHE INTERNAL "" FORCE)



#! Create a new test that can be run by CTest or `qibuild test`
#
# Notes:
#  * The resulting executable will not be installed
#  * The name of the test will always be the name of the target.
#  * The test won't be built if BUILD_TESTS is OFF
#
# .. seealso::
#
#    * :ref:`qibuild-ctest`
#
# \arg:name the name of the test and the target
# \group:SRC  sources of the test
# \group:DEPENDS the dependencies of the test
# \param:TIMEOUT the timeout of the test
# \group:ARGUMENTS arguments to be passed to the executable
# \flag:SLOW mark the test as slow, so that it is only run with ``qibuild test --slow``
# \argn: source files (will be merged with the SRC group of arguments)
function(qi_create_test name)
  if (DEFINED BUILD_TESTS AND NOT BUILD_TESTS)
    qi_debug("Test(${name}) disabled by BUILD_TESTS=OFF")
    qi_set_global(QI_${name}_TARGET_DISABLED TRUE)
    return()
  endif()
  cmake_parse_arguments(ARG "SLOW" "TIMEOUT" "SRC;DEPENDS;ARGUMENTS" ${ARGN})
  if(ARG_SLOW)
    set(_slow "SLOW")
  else()
    set(_slow "")
  endif()
  qi_create_bin(${name} SRC ${ARG_SRC} ${ARG_UNPARSED_ARGUMENTS} NO_INSTALL)
  if(ARG_DEPENDS)
    qi_use_lib(${name} ${ARG_DEPENDS})
  endif()
  qi_add_test(${name} ${name}
    TIMEOUT ${ARG_TIMEOUT}
    ARGUMENTS ${ARG_ARGUMENTS}
    ${_slow}
  )
endfunction()


#! This compiles and add a test using gtest that can be run by CTest or
# `qibuild test`
#
# When running ctest, an XML xUnit file wiil be created in
# ${CMAKE_SOURCE_DIR}/test-results/${test_name}.xml
#
# Notes:
#
#  * The test won't be built at all if GTest is not found.
#  * The name of the test will always be the name of the target.
#
# .. seealso::
#
#    * :ref:`qibuild-ctest`
#
# \arg:name name of the test
# \flag:NO_ADD_TEST Do not call add_test, just create the binary
# \flag:SLOW mark the test as slow, so that it is only run with ``qibuild test --slow``
# \argn: source files, like the SRC group, argn and SRC will be merged
# \param:TIMEOUT The timeout of the test
# \group:SRC Sources
# \group:DEPENDS Dependencies to pass to use_lib
# \group:ARGUMENTS Arguments to pass to add_test (to your test program)
#
function(qi_create_gtest name)
  if (DEFINED BUILD_TESTS AND NOT BUILD_TESTS)
    qi_debug("Test(${name}) disabled by BUILD_TESTS=OFF")
    qi_set_global(QI_${name}_TARGET_DISABLED TRUE)
    return()
  endif()

  if(NOT DEFINED GTEST_PACKAGE_FOUND)
    find_package(GTEST NO_MODULE)
    if(NOT GTEST_PACKAGE_FOUND)
      qi_set_global(GTEST_PACKAGE_FOUND FALSE)
    endif()
  endif()

  if(NOT GTEST_PACKAGE_FOUND)
    if(NOT QI_CREATE_GTEST_WARNED)
      qi_info("GTest was not found:
      qi_create_gtest will create no target
      ")
      qi_set_global(QI_CREATE_GTEST_WARNED TRUE)
    endif()
    qi_set_global(QI_${name}_TARGET_DISABLED TRUE)
    return()
  endif()

  set(_using_qibuild_gtest TRUE)
  # Make sure we are using the qibuild flavored gtest
  # package:
  find_package(gtest_main QUIET)
  if(NOT GTEST_MAIN_PACKAGE_FOUND)
    set(_using_qibuild_gtest FALSE)
    if(NOT QI_GTEST_QIBUID_WARNED)
      qi_info("Could not find qibuild flavored gtest. (not GTEST_MAIN package)
      Please use a qibuild port of gtest or be ready to
      experience weird link errors ...
      ")
      qi_set_global(QI_GTEST_QIBUID_WARNED TRUE)
    endif()
  endif()

  # create tests_results folder if it does not exist
  file(MAKE_DIRECTORY "${_TESTS_RESULTS_FOLDER}")
  cmake_parse_arguments(ARG "SLOW;NO_ADD_TEST" "TIMEOUT" "SRC;DEPENDS;ARGUMENTS" ${ARGN})
  if(ARG_SLOW)
    set(_slow "SLOW")
  else()
    set(_slow "")
  endif()

  # First, create the target
  qi_create_bin(${name} SRC ${ARG_SRC} ${ARG_UNPARSED_ARGUMENTS} NO_INSTALL)
  qi_use_lib(${name} GTEST ${ARG_DEPENDS})
  if(${_using_qibuild_gtest})
    qi_use_lib(${name} GTEST_MAIN)
  endif()

  # Build a correct xml output name
  set(_xml_output "${_TESTS_RESULTS_FOLDER}/${name}.xml")

  if (WIN32)
    string(REPLACE "/" "\\\\" xml_output ${_xml_output})
  endif()


  # Call qi_add_test with correct arguments:
  # first, --gtest_output:
  set(_args --gtest_output=xml:${_xml_output})

  # then, arguments coming from the user:
  list(APPEND _args  ${ARG_ARGUMENTS})

  qi_add_test(${name} ${name}
    TIMEOUT ${ARG_TIMEOUT}
    ARGUMENTS ${_args}
    ${_slow}
  )
endfunction()

#! Add a test using a binary that was created by :cmake:function:`qi_create_bin`
#
# This calls ``add_test()`` with the same arguments but:
#
#  * We look for the binary in sdk/bin, and we know
#    there is a _d when using Visual Studio
#  * We set a 'tests' folder property
#  * We make sure necessary environment variables are set on mac
#
# This is a low-level function, you should rather use
# :cmake:function:`qi_create_test` or :cmake:function:`qi_create_gtest` instead.
#
# \arg:test_name The name of the test
# \arg:target_name The name of the binary to use
# \param:TIMEOUT The timeout of the test
# \group:ARGUMENTS Arguments to be passed to the executable
# \flag:SLOW mark the test as slow, so that it is only run with ``qibuild test --slow``
#
function(qi_add_test test_name target_name)
  cmake_parse_arguments(ARG "SLOW" "TIMEOUT" "ARGUMENTS" ${ARGN})

  if(NOT ARG_TIMEOUT)
    set(ARG_TIMEOUT 20)
  endif()

  set(_bin_path ${QI_SDK_DIR}/${QI_SDK_BIN}/${target_name})

  if(MSVC AND "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(_bin_path ${_bin_path}_d)
  endif()

  add_test(${test_name} ${_bin_path} ${ARG_ARGUMENTS})

  # Be nice with Visual Studio users:
  set_target_properties(${target_name}
    PROPERTIES
      FOLDER "tests")

  set_tests_properties(${test_name} PROPERTIES
    TIMEOUT ${ARG_TIMEOUT}
  )

  if(ARG_SLOW)
    set_tests_properties(${test_name} PROPERTIES COST 100)
  else()
    set_tests_properties(${test_name} PROPERTIES COST 1)
  endif()

  # HACK for apple until the .dylib problems are fixed...
  if(APPLE)
    set_tests_properties(${test_name} PROPERTIES
      ENVIRONMENT "DYLD_LIBRARY_PATH=${QI_SDK_DIR}/${QI_SDK_LIB};DYLD_FRAMEWORK_PATH=${QI_SDK_DIR}"
    )
  endif()
endfunction()
