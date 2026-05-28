# API Reference

Base URL: `http://<ALB-DNS>/api`

## Authentication

### POST /auth/register

```json
// Request
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "Password1"
}

// Response 201
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": { "id": "uuid", "username": "johndoe", "email": "...", "role": "customer" },
    "accessToken": "eyJ...",
    "refreshToken": "eyJ..."
  }
}
```

### POST /auth/login

```json
// Request
{ "email": "john@example.com", "password": "Password1" }

// Response 200
{
  "success": true,
  "data": { "user": {...}, "accessToken": "eyJ...", "refreshToken": "eyJ..." }
}
```

### POST /auth/logout
**Auth required.** Returns 200.

### GET /auth/profile
**Auth required.** Returns user object.

---

## Products

### GET /products

Query params: `page` (default 1), `limit` (default 12), `category`, `search`

```json
// Response 200
{
  "data": {
    "products": [{ "id": "uuid", "name": "...", "price": "99.99", "stock": 10, ... }],
    "pagination": { "total": 20, "page": 1, "limit": 12, "pages": 2 }
  }
}
```

### GET /products/:id

Returns single product or 404.

### POST /products — Admin only

```json
// Request
{
  "name": "New Product",
  "price": 99.99,
  "stock": 10,
  "category": "Electronics",
  "description": "...",
  "image_url": "https://..."
}
```

### PUT /products/:id — Admin only

Same body as POST. Returns updated product.

### DELETE /products/:id — Admin only

Soft-delete (sets `is_active: false`). Returns 200.

---

## Cart

All cart endpoints require authentication.

### GET /cart

Returns cart with items and total.

### POST /cart/items

```json
{ "product_id": "uuid", "quantity": 2 }
```

### PUT /cart/items/:id

```json
{ "quantity": 3 }
```

### DELETE /cart/items/:id

Removes single item.

### DELETE /cart

Clears all items.

---

## Orders

All order endpoints require authentication.

### POST /orders/checkout

```json
// Request
{
  "shipping_address": {
    "name": "John Doe",
    "address": "123 Main St",
    "city": "New York",
    "zip": "10001",
    "country": "United States"
  },
  "payment": {
    "card_number": "4111111111111111",
    "expiry": "12/26",
    "cvv": "123"
  }
}

// Response 201
{
  "data": {
    "order": { "id": "uuid", "total_amount": "299.98", "status": "processing", "payment_status": "paid", ... },
    "transaction_id": "TXN-1716000000000"
  }
}
```

### GET /orders

Returns list of user's orders.

### GET /orders/:id

Returns single order with items.

---

## Health

### GET /health

```json
// Response 200
{
  "status": "healthy",
  "uptime": 3600.5,
  "timestamp": "2026-05-28T10:00:00.000Z",
  "environment": "production"
}
```

---

## Error Responses

```json
// 400 Bad Request
{ "success": false, "message": "Validation failed", "errors": [...] }

// 401 Unauthorized
{ "success": false, "message": "No token provided" }

// 403 Forbidden
{ "success": false, "message": "Admin access required" }

// 404 Not Found
{ "success": false, "message": "Product not found" }

// 409 Conflict
{ "success": false, "message": "Email already registered" }

// 429 Too Many Requests
{ "success": false, "message": "Too many requests, please try again later." }

// 500 Internal Server Error
{ "success": false, "message": "Internal server error" }
```
