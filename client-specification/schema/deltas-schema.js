const Joi = require('joi');
const deltaEventSchema = require('./delta-event-schema.js');

const deltasSchema = Joi.object({
    events: Joi.array().items(deltaEventSchema).required(),
});

module.exports = deltasSchema;