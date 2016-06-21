`void vm_init();`

This initializes the VM.

```
init_strings();

All strings are stored in an extensible hash table, with reference counts

free_string() decreases the reference count;
if reference count goes to zero, the string is deallocated.

add_string() increases the ref count if it finds a match
or allocates it if it can't.
```

```
init_identifiers();

Initializes the identifiers hash tables.
```

```
init_locals();

Initializes the local variables.
```

```
init_otable();

Initializes the object hash table.
```

```
set_inc_list();

Sets the files/directories to be included.
```

```
add_predefines();

Adds initial predefines.
```

```
reset_machine(1);

Resets the 'csp' and 'sp' registers of the VM.
```

```
init_simul_efun(__SIMUL_EFUN_FILE__);

Loads in all simul efuns from this file.
```

```
init_master(__MASTER_FILE__);

Initializes the master object from this file.
```


```
init_posix_timers();

Initializes all VM timers.
```

```
preload_objects();

The master file will return an array of files to load, (via epilog())
This function loads in all of those files.
```
