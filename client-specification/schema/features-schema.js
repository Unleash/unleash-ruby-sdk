const Joi = require('joi');
const featureSchema = require('./feature-schema');
const segmentSchema = require('./segment-schema');

const featuresSchema = Joi.object().keys({
    version: Joi.number().min(1).required(),
    features: Joi.array().items(featureSchema),
    segments: Joi.array().items(segmentSchema)
});

module.exports = featuresSchema;