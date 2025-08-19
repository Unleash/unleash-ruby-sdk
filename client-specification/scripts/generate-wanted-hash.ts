#!/usr/bin/env -S deno run

import { Command } from "https://deno.land/x/cliffy@v1.0.0-rc.3/command/mod.ts";
import murmurHash3 from "npm:murmurhash3js";

function getNumber(group: string, identifier: string, seed: number, normalise: number): number {
  return (murmurHash3.x86.hash32(`${group}:${identifier}`, seed) % normalise) + 1;
}

const options = await new Command()
  .name("hasher")
  .description("A simple murmur hash generator")
  .version("v1.0.0")
  .option("-s --seed <seed:number>", "The seed for murmur", { default: 0 })
  .option("-g --group <group:string>", "The group you want to hash")
  .option("-i --identifier <identifier:string>", "The identifier")
  .option("-n --normalise <normalise:number>", "The number to normalise to", { default: 100 })
  .action((options, ...args) => {
    console.log(`Hashing ${options.group}:${options.identifier} with seed ${options.seed} and normalising within 1 to ${options.normalise}`)
    console.log(`Hash: ${getNumber(options.group, options.identifier, options.seed, options.normalise)}`);
  })
  .parse(Deno.args);
