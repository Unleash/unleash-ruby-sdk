const Joi = require('joi');
const chalk = require('chalk');

const testCaseSchema = require('./schema/test-case-schema');
const testCases = require('./specifications/index.json');

testCases.forEach(name => {
    const testCase = require(`./specifications/${name}`);
    const { error, value } = testCaseSchema.validate(testCase)

    if (error) {
        console.error(`${name} ${chalk.red('is not valid')}. \n`, error);
        process.exitCode(1);
    } else {
        console.log(`${name} ${chalk.green('is valid')}`);
    }
});
