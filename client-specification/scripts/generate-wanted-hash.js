'use strict';

const murmurHash3 = require('murmurhash3js');

function getTarget (name, id, total, seed) {
  console.log(`Hashing ${name}:${id} with seed ${seed}`);
    return (murmurHash3.x86.hash32(`${name}:${id}`, seed) % total) + 1;
}


function findTarget (name, total, wantedTarget, seed) {
    let found = false;
    let iterations = 0;
    while(!found) {
        iterations++;
        const id = Math.round(Math.random() * Math.random() * 1000);
        const target = getTarget(name, id, total, seed);
        if (target === wantedTarget) {
            console.log(`If you give userId "${id}" with toggleName "${name}" it will give you allocation "${target}"`);
            found = true;
        }
        if (iterations == 100000) {
            throw new Error('1000 tries is enough');
        }
        
    }
}

/*const toggleName = 'name';
findTarget(toggleName, 100, 25);
findTarget(toggleName, 100, 50);
findTarget(toggleName, 100, 30);
findTarget(toggleName, 100, 80);
findTarget(toggleName, 100, 100);
*/

const [bin, file, name, total, wanted, seed] = process.argv;
if (!name || !total || !wanted) {
    console.error(`Usage:
    $ node scripts/generate-wanted-hash.js toggleName 100 25 <seed>

    100 = total number
    25 = wanted allocation
    <seed> = seed to use to murmur. Default to 0
    
    `);
    return;
}


findTarget(String(name), Number(total), Number(wanted), Number(seed || 0));

