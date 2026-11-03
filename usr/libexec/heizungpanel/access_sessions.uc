import { open } from 'fs';

let input = open('/dev/stdin', 'r');
let count = 0;
let line;
while ((line = input.read('line')) != null) {
    if (!length(trim(line)))
        continue;
    let session = json(line);
    if (type(session) != 'object')
        exit(2);
    if (type(session.data?.username) == 'string' &&
        type(session.data?.token) == 'string' &&
        (session.timeout == 0 || session.expires >= 0))
        count++;
}
input.close();
print(count, '\n');
