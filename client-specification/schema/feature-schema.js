const Joi = require('joi');

const featureSchema = Joi.object().keys({
    name: Joi.string().required(),
    description: Joi.string().optional(),
    enabled: Joi.boolean().required(),
    project: Joi.string().optional(),
    type: Joi.string().optional(),
    description: Joi.string().optional().allow(null),
    impressionData: Joi.boolean().optional(),
    stale: Joi.boolean().optional(),
    dependencies: Joi.array().optional().items(
        Joi.object().keys({
            feature: Joi.string().required(),
            enabled: Joi.bool().optional(),
            variants: Joi.array().items(Joi.string()).optional()
        })
    ),
    segments: Joi.array().items(Joi.number()),
    strategies: Joi.array().items(
        Joi.object().keys({
            name: Joi.string().required(),
            parameters: Joi.object(),
            variants: Joi.array().items(
                Joi.object().keys({
                    name: Joi.string().required(),
                    payload: Joi.object().required().keys({
                        type: Joi.string().required(),
                        value: Joi.string().required().allow(""),
                    }).optional(),
                    weight: Joi.number().min(0).max(100000),
                    stickiness: Joi.string().optional(),
                })
            ).optional(),
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
            segments: Joi.array().items(Joi.number()).optional()
        })
    ),
    variants: Joi.array().items(
        Joi.object().keys({
            name: Joi.string().required(),
            payload: Joi.object().required().keys({
                type: Joi.string().required(),
                value: Joi.string().required().allow(""),
            }).optional(),
            weight: Joi.number().min(0).max(100000),
            stickiness: Joi.string().optional(),
            overrides: Joi.array().items(
                Joi.object().keys({
                    contextName: Joi.string().required(),
                    values: Joi.array().items(Joi.string()),
                }).optional()
            ),
        })
    )
});

module.exports = featureSchema;
