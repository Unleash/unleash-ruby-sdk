const Joi = require('joi');
const featureSchema = require('./feature-schema');
const segmentSchema = require('./segment-schema');

const deltaEventSchema = Joi.alternatives().try(
    Joi.object({
        eventId: Joi.number().required(),
        type: Joi.string().valid("hydration").required(),
        segments: Joi.array().items(segmentSchema).optional(),
        features: Joi.array().items(featureSchema).required(),
    }),
    Joi.object({
        eventId: Joi.number().required(),
        type: Joi.string().valid("feature-updated").required(),
        feature: featureSchema.required(),
    }),
    Joi.object({
        eventId: Joi.number().required(),
        type: Joi.string().valid("feature-removed").required(),
        featureName: Joi.string().required(),
        project: Joi.string().required(),
    }),
    Joi.object({
        eventId: Joi.number().required(),
        type: Joi.string().valid("segment-updated").required(),
        segment: segmentSchema.required(),
    })
);

module.exports = deltaEventSchema;
