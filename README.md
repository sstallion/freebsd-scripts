# Administration Scripts

This repository contains scripts used to administer FreeBSD systems. Most
scripts are self-explanatory; for those that require additional documentation, a
separate `README` is provided.

## Installation

To install on a new system, issue:
```
# git clone https://github.com/sstallion/freebsd-scripts.git /var/scripts
```

> [!NOTE]
> Scripts that must be located in a specific path (eg. `periodic(8)` and
> `rc(8)`) should be symlinked rather than copied to track upstream changes.

### Updates

Daily updates can be enabled by adding `daily_scripts_update_enable="YES"` to
`/etc/periodic.conf` or `/etc/periodic.conf.local` and issuing:
```
# ln -s /var/scripts/periodic/999.scripts-update /usr/local/etc/periodic/daily
```

## Contributing

Pull requests are welcome! If a problem is encountered using this repository,
please file an issue on [GitHub][1].

## License

Source code in this repository is licensed under a Simplified BSD License. See
[LICENSE][2] for details.

[1]: https://github.com/sstallion/freebsd-scripts/issues
[2]: https://github.com/sstallion/freebsd-scripts/blob/master/LICENSE
