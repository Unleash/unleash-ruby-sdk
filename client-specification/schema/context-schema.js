const Joi = require('joi');

const schema = Joi.object().keys({
    userId: Joi.string(),
    sessionId: Joi.string(),
    remoteAddress: Joi.string().optional(),
    currentTime: Joi.string().optional(),
    environment: Joi.string().optional(),
    appName: Joi.string(),
    properties: Joi.object().pattern(/\w+/, Joi.string().allow(null)),
})

module.exports = schema;