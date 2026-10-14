# Batch Member Creation

The `create-batch` command allows you to create multiple IBM i source members in a single operation, which is particularly useful when working with multiple programs or members that share the same source type.

## Usage

```bash
isync member create-batch <srcfile> <srctype> <member1> <member2> ...
```

### Parameters

- `<srcfile>`: Source file name (e.g., `QRPGLESRC`, `QCLLESRC`)
- `<srctype>`: Source type for all members (e.g., `RPGLE`, `CLLE`, `SQL`)
- `<member1> <member2> ...`: One or more member names to create

## Examples

### Create Multiple RPGLE Members

```bash
# Create three RPGLE members in the QRPGLESRC source file
isync member create-batch QRPGLESRC RPGLE PROG1 PROG2 PROG3
```

### Create Multiple CL Members

```bash
# Create two CL members in the QCLLESRC source file
isync member create-batch QCLLESRC CLLE CLPROG1 CLPROG2
```

### Create Members with Library Override

```bash
# Create members in a specific library using --library flag
isync --library=MYLIB member create-batch QRPGLESRC RPGLE PROG1 PROG2
```

## Benefits

- **Reduced Repetition**: Instead of creating members one by one, create them all at once
- **Consistent Source Types**: All members get the same source type, reducing errors
- **Efficiency**: Single operation for multiple members
- **Batch Operations**: Ideal for new development projects or refactoring

## Error Handling

If any member creation fails, the command will continue with remaining members and report the failures:

```bash
$ isync member create-batch QRPGLESRC RPGLE PROG1 PROG2 PROG3

Creating 3 member(s) in DEVLIB/QRPGLESRC...
Member created: DEVLIB/QRPGLESRC(PROG1)
Member created: DEVLIB/QRPGLESRC(PROG2)
Member already exists: DEVLIB/QRPGLESRC(PROG3)
Failed: 1 member(s)
```

## Notes

- Members will be created in the effective library (from session context, profile, or override)
- The source type applies to all members in the batch
- If a member already exists, it will be skipped with a warning
- Password caching works for all operations in the batch