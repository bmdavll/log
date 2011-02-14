===
LOG
===

--------------------------------------------------------------
A command-line interface for displaying and managing text logs
--------------------------------------------------------------

``log`` is a utility that allows you to easily access, print, search, and
edit your text logs and notes.  There are several graphical applications
(such as GNOME's Tomboy) for managing notes/stickies.  However, if you do a
lot of work on the command line or have a preferred text editor, they can
feel counterproductive or limiting.  ``log`` is the command-line alternative
that combines a simple and intuitive interface with the power and
flexibility of your favorite editor.

Files managed by this utility start with the header ``#!log`` and consist of
either delimited entries or regular lines, with comments marked by ``#``.  A
command consists of an optional file argument and a keyword (usually a
single letter) for the operation.  The file argument names a file within the
directory named by the ``$LOG_DIR`` environment variable, or relative or
absolute path to an existing log file.  Some examples:

To print the default log::

  log p

Print the last entry that contains the case insensitive patterns *foo.*bar*
and *baz* on the first line::

  log pl -i "foo.*bar" "baz"

Print a one-line summary for each of the last 10 entries of the file
``foo/bar`` under ``$LOG_DIR``::

  log foo/bar o -10

Count the number of entries that contain *foo* but not *bar* on the first
line::

  log c foo :bar

Edit the first entry that contains the pattern *bear* anywhere::

  log ef bear -s

Print a random entry from the ``recipes`` log::

  log recipes m

Delete the first 4 lines/entries from the log file ``books`` in your home
directory::

  log ~/books d +4

Append a line to ``movies``::

  log movies a  Harold and Maude

Append an entry to the default log using input from ``stdin``::

  cat foo.txt | log a -

Insert a new line "*2 get bacon*" in sorted order into the ``todo`` log::

  log todo s  2 get bacon

Create ``new`` log file in ``$LOG_DIR`` with entries delimited by "``>>``"::

  log n'>>' new

``log`` is the script that provides the interface, while ``entries.pl`` does
the text processing.  For documentation, please see ``log --help`` and
``entries.pl --help``.


Installation
============

1. Make ``entries.pl`` and ``log`` executable and available in one of your
   ``$PATH`` directories.

2. Edit ``log_completion.sh`` and setup environment variables ``$LOG_DIR``,
   ``$EDITOR``, and ``$LOG_EDITOR``. If your shell is not ``bash``, setup
   and export those variables in your shell startup config.

3. Add lines to your ``.bashrc`` to source ``log_completion.sh`` and
   ``rand_completion.sh``::

    . /path/to/log_completion.sh
    . /path/to/rand_completion.sh


See the ``examples`` directory for example log files and scripts.


Dependencies
------------

``log`` and ``entries.pl`` run on any POSIX-compliant system with
``coreutils``, ``bash``, ``awk``, and ``perl`` >= 5.10.0.


Usage
=====

Use ``log h`` to print the usage string.

``log`` comes with ``bash`` command-line completion--when in doubt, press
``TAB``!

Don't do this; you'll be deleting entries 2 and 4::

  log o
  log d 2
  log d 3

Instead, enter the ``d`` commands in reverse, or (a better way)::

  log d <TAB>   # to examine the file, then...
  log d 2 3

Also, this will print a preview of the entry in question::

  log d 2<TAB>

Tips
----

``log`` uses the directory structure under ``$LOG_DIR`` to organize log
files.  This command will first check ``$LOG_DIR/foo/bar``, then
``./foo/bar``::

  log foo/bar

To specifically access a file outside ``$LOG_DIR``, use any of the
following::

  log /absolute/path
  log ./path
  log ../path

``log`` was written with ``vim`` integration in mind.  If your editor is set
to a flavor of ``vim``, ``log`` will read a modeline in the header.

Section delimiters can double as fold markers if all of them have the same
fold level::

  #!log [-]1
  [-]1
  Entry 1
  ...
  [-]1
  Entry 2

To conveniently expand and collapse folds, add this bind to your .vimrc::

  noremap <silent> <Space> :<C-U>exec 'silent! normal! za'<CR>

Graphical stickies applications often have the ability to link between
notes.  The same thing can be achieved in ``vim`` by using the ``gf``
command over the name of a log file in order to jump there.


Author
======

David Liang (bmdavll at gmail.com)


License
=======

``log`` is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

``log`` is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ``log``.  If not, see <http://www.gnu.org/licenses/>.


.. vim:set ts=2 sw=2 et tw=76:
