# Reports

## Test Status

`spec/**/*.spec`

|      File       |      100%       |     Passed      |     Pending     |
|-----------------|-----------------|-----------------|-----------------|
| cat.spec        | false           |  89% (8/9)      |  11% (1/9)      |
| ls.spec         | false           |  94% (17/18)    |   6% (1/18)     |
| put.spec        | false           |  94% (15/16)    |   6% (1/16)     |
| server.spec     | true            | 100% (20/20)    |                 |
| directory-entry | false           |  72% (256/357)  |   6% (20/357)   |
| path-entry.spec | false           |  82% (156/190)  |   5% (10/190)   |
| async.spec      | true            | 100% (5/5)      |                 |
| bit-field.spec  | true            | 100% (101/101)  |                 |
| decoder.spec    | true            | 100% (23/23)    |                 |


## Protocol Coverage

Overview of how perfect the protocol requests are.

### Client API

Driver
: `spec/integration/client`

|      File       |      100%       |     Passed      |     Pending     |
|-----------------|-----------------|-----------------|-----------------|
| Tattach         | false           |  67% (12/18)    |                 |
| Tauth           | true            | 100% (1/1)      |                 |
| Tclunk          | false           |  89% (24/27)    |                 |
| Tcreate         | false           |                 |                 |
| Tflush          | false           |                 |                 |
| Tgetattr        | false           |                 |                 |
| Tlink           | false           |                 |                 |
| Tlopen          | false           |  57% (72/127)   |                 |
| Tmkdir          | false           |                 |                 |
| Tmknod          | false           |                 |                 |
| Topen           | false           |                 |                 |
| Tread           | false           |  58% (34/59)    |  20% (12/59)    |
| Treaddir        | false           |  88% (155/177)  |                 |
| Treadlink       | false           |                 |                 |
| Tremove         | false           |                 |                 |
| Trename         | false           |                 |                 |
| Tsetattr        | false           |                 |                 |
| Tstat           | false           |                 |                 |
| Tstatfs         | false           |  96% (23/24)    |                 |
| Tsymlink        | false           |                 |                 |
| Tversion        | false           |  60% (3/5)      |                 |
| Twalk           | false           |  91% (30/33)    |   9% (3/33)     |
| Twrite          | false           |  89% (47/53)    |  11% (6/53)     |
| Twstat          | false           |                 |                 |
| unknown         | false           |  93% (200/215)  |   6% (12/215)   |


### Manual requests

Driver
: `spec/integration/requests`

|      File       |      100%       |     Passed      |     Pending     |
|-----------------|-----------------|-----------------|-----------------|
| Tattach         | false           |  71% (15/21)    |                 |
| Tauth           | false           |                 |                 |
| Tclunk          | false           |  91% (30/33)    |                 |
| Tcreate         | false           |                 |                 |
| Tflush          | false           |                 | 100% (3/3)      |
| Tgetattr        | false           |                 | 100% (33/33)    |
| Tlink           | false           |                 | 100% (3/3)      |
| Tlopen          | false           |  45% (77/173)   |                 |
| Tmkdir          | false           |                 | 100% (3/3)      |
| Tmknod          | false           |                 | 100% (3/3)      |
| Topen           | false           |                 | 100% (3/3)      |
| Tread           | false           |  76% (35/46)    |  13% (6/46)     |
| Treaddir        | false           |                 | 100% (15/15)    |
| Treadlink       | false           |                 | 100% (3/3)      |
| Tremove         | false           |                 | 100% (3/3)      |
| Trename         | false           |                 | 100% (3/3)      |
| Tsetattr        | false           |                 | 100% (3/3)      |
| Tstat           | false           |                 |                 |
| Tstatfs         | true            | 100% (18/18)    |                 |
| Tsymlink        | false           |                 | 100% (3/3)      |
| Tversion        | false           |  51% (18/35)    |                 |
| Twalk           | false           |  91% (30/33)    |   9% (3/33)     |
| Twrite          | false           |                 | 100% (57/57)    |
| Twstat          | false           |                 |                 |
| unknown         | false           |  14% (6/42)     |  86% (36/42)    |

