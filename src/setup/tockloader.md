# Familiarize Yourself with `tockloader` Commands

The `tockloader` tool is a useful and versatile tool for managing and installing
applications on Tock. It supports a number of commands, and a more complete list
can be found in the tockloader repository, located at
[github.com/tock/tockloader](https://github.com/tock/tockloader#usage). Below is
a list of the more useful and important commands for programming and querying a
board.

## `tockloader install`

This is the main tockloader command, used to load Tock applications onto a
board. By default, `tockloader install` adds the new application, but does not
erase any others, replacing any already existing application with the same name.
Use the `--no-replace` flag to install multiple copies of the same app. To
install an app, either specify the `tab` file as an argument, or navigate to the
app's source directory, build it (probably using `make`), then issue the install
command:

    $ tockloader install

> _Tip:_ You can add the `--make` flag to have tockloader automatically run make
> before installing, i.e. `tockloader install --make`

> _Tip:_ You can add the `--erase` flag to have tockloader automatically remove
> other applications when installing a new one.

## `tockloader uninstall [application name(s)]`

Removes one or more applications from the board by name.

## `tockloader erase-apps`

Removes all applications from the board.

## `tockloader list`

Prints basic information about the apps currently loaded onto the board.

## `tockloader info`

Shows all properties of the board, including information about currently loaded
applications, their sizes and versions, and any set attributes.

## `tockloader listen`

This command prints output from Tock apps to the terminal. It listens via UART,
and will print out anything written to stdout/stderr from a board.

> _Tip:_ As a long-running command, `listen` interacts with other tockloader
> sessions. You can leave a terminal window open and listening. If another
> tockloader process needs access to the board (e.g. to install an app update),
> tockloader will automatically pause and resume listening.

## `tockloader flash`

Loads binaries onto hardware platforms that are running a compatible bootloader.
This is used by the Tock Make system when kernel binaries are programmed to the
board with `make program`.
