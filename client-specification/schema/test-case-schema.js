const Joi = require('joi');
const featuresSchema = require('./features-schema.js');
const deltasSchema = require('./deltas-schema.js');
const contextSchema = require('./context-schema.js');

const schema = Joi.object().keys({
    name: Joi.string(),
    state: Joi.alternatives().try(featuresSchema, deltasSchema).required(),
    tests: Joi.array().items(
        Joi.object().keys({
            description: Joi.string().required(),
            context: contextSchema,
            toggleName: Joi.string().required(),
            expectedResult: Joi.boolean().required(),
        })
    ),
    variantTests: Joi.array().items(
        Joi.object().keys({
            description: Joi.string().required(),
            context: contextSchema,
            toggleName: Joi.string().required(),
            expectedResult: Joi.object().required().keys({
                name: Joi.string().required(),
                payload: Joi.object().required().keys({
                    type: Joi.string().required(),
                    value: Joi.string().required().allow(""),
                }).optional(),
                enabled: Joi.boolean().required(),
                feature_enabled: Joi.boolean().required()
            }),
        })
    )
});

module.exports = schema;
