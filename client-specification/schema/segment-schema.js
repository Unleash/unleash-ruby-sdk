const Joi = require('joi');

const segmentSchema = Joi.object().keys({
    id: Joi.number().required(),
    name: Joi.string().optional().allow(null),
    constraints: Joi.array().items(
        Joi.object().keys({
            contextName: Joi.string().required(),
            operator: Joi.string().required(),
            values: Joi.array().items(Joi.string()),
            caseInsensitive: Joi.bool().optional(),
            inverted: Joi.bool().optional(),
            value: Joi.string().optional()
        }).optional()
    ),
});

module.exports = segmentSchema;
