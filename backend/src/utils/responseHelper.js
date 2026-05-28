const success = (res, data = null, message = 'OK', statusCode = 200) => {
  const body = { success: true, message };
  if (data !== null) body.data = data;
  return res.status(statusCode).json(body);
};

const created = (res, data, message = 'Created') =>
  success(res, data, message, 201);

const error = (res, message = 'Internal Server Error', statusCode = 500, errors = null) => {
  const body = { success: false, message };
  if (errors) body.errors = errors;
  return res.status(statusCode).json(body);
};

const notFound = (res, message = 'Not found') => error(res, message, 404);

const unauthorized = (res, message = 'Unauthorized') => error(res, message, 401);

const forbidden = (res, message = 'Forbidden') => error(res, message, 403);

const badRequest = (res, message = 'Bad request', errors = null) =>
  error(res, message, 400, errors);

module.exports = { success, created, error, notFound, unauthorized, forbidden, badRequest };
