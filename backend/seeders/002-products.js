'use strict';

const { v4: uuidv4 } = require('uuid');

const products = [
  { name: 'Laptop Pro 15"', description: 'Laptop de alto rendimiento con procesador i7, 16GB RAM, SSD 512GB', price: 1299.99, stock: 15, category: 'Electrónica', image_url: 'https://via.placeholder.com/400x300?text=Laptop+Pro' },
  { name: 'Mouse Inalámbrico Ergonómico', description: 'Mouse ergonómico con conexión Bluetooth y batería recargable', price: 49.99, stock: 50, category: 'Periféricos', image_url: 'https://via.placeholder.com/400x300?text=Mouse' },
  { name: 'Teclado Mecánico RGB', description: 'Teclado mecánico con switches Cherry MX Red e iluminación RGB', price: 129.99, stock: 30, category: 'Periféricos', image_url: 'https://via.placeholder.com/400x300?text=Teclado' },
  { name: 'Monitor 27" 4K', description: 'Monitor Ultra HD 4K con panel IPS y tiempo de respuesta 1ms', price: 449.99, stock: 10, category: 'Monitores', image_url: 'https://via.placeholder.com/400x300?text=Monitor+4K' },
  { name: 'Headset Gaming 7.1', description: 'Auriculares gaming con sonido surround 7.1 y micrófono cancelador de ruido', price: 89.99, stock: 25, category: 'Audio', image_url: 'https://via.placeholder.com/400x300?text=Headset' },
  { name: 'Webcam Full HD 1080p', description: 'Cámara web Full HD con autoenfoque y corrección de luz automática', price: 69.99, stock: 40, category: 'Periféricos', image_url: 'https://via.placeholder.com/400x300?text=Webcam' },
  { name: 'SSD Externo 1TB', description: 'Disco sólido externo USB-C con velocidades de transferencia de hasta 1050 MB/s', price: 109.99, stock: 20, category: 'Almacenamiento', image_url: 'https://via.placeholder.com/400x300?text=SSD' },
  { name: 'Hub USB-C 7 en 1', description: 'Adaptador multipuerto con HDMI 4K, USB 3.0, SD card y carga rápida 100W', price: 39.99, stock: 60, category: 'Accesorios', image_url: 'https://via.placeholder.com/400x300?text=Hub+USB' },
  { name: 'Silla Gaming Profesional', description: 'Silla ergonómica con soporte lumbar ajustable, reposabrazos 4D y base de aluminio', price: 299.99, stock: 8, category: 'Mobiliario', image_url: 'https://via.placeholder.com/400x300?text=Silla+Gaming' },
  { name: 'Smartphone 5G Pro', description: 'Teléfono inteligente con pantalla AMOLED 6.7", cámara 108MP y batería 5000mAh', price: 899.99, stock: 12, category: 'Electrónica', image_url: 'https://via.placeholder.com/400x300?text=Smartphone' },
  { name: 'Tablet 11" WiFi', description: 'Tablet con pantalla Retina 11", procesador M1 y autonomía de 10 horas', price: 599.99, stock: 18, category: 'Electrónica', image_url: 'https://via.placeholder.com/400x300?text=Tablet' },
  { name: 'Impresora Láser Color', description: 'Impresora láser a color con WiFi, dúplex automático y velocidad 28ppm', price: 349.99, stock: 7, category: 'Impresoras', image_url: 'https://via.placeholder.com/400x300?text=Impresora' },
  { name: 'Router WiFi 6 AX3000', description: 'Router de última generación WiFi 6 con cobertura de hasta 230m² y MU-MIMO', price: 159.99, stock: 22, category: 'Redes', image_url: 'https://via.placeholder.com/400x300?text=Router' },
  { name: 'Cargador Inalámbrico 15W', description: 'Cargador Qi rápido 15W compatible con iPhone y Android', price: 24.99, stock: 80, category: 'Accesorios', image_url: 'https://via.placeholder.com/400x300?text=Cargador' },
  { name: 'Alfombrilla XL Gaming', description: 'Alfombrilla de escritorio XL 90x40cm con base antideslizante y superficie optimizada', price: 34.99, stock: 45, category: 'Accesorios', image_url: 'https://via.placeholder.com/400x300?text=Alfombrilla' },
  { name: 'Micrófono Condensador USB', description: 'Micrófono de estudio con patrón cardioide, filtro pop y soporte articulado', price: 119.99, stock: 15, category: 'Audio', image_url: 'https://via.placeholder.com/400x300?text=Microfono' },
  { name: 'Memoria RAM DDR5 32GB', description: 'Kit de memoria RAM DDR5 32GB (2x16GB) 5600MHz para gaming y workstations', price: 179.99, stock: 28, category: 'Componentes', image_url: 'https://via.placeholder.com/400x300?text=RAM+DDR5' },
  { name: 'Tarjeta Gráfica RTX 4070', description: 'GPU para gaming con 12GB GDDR6X y soporte ray tracing de última generación', price: 599.99, stock: 5, category: 'Componentes', image_url: 'https://via.placeholder.com/400x300?text=GPU' },
  { name: 'Smart TV 55" OLED', description: 'Televisor OLED 55" 4K con HDR Dolby Vision, Smart TV y panel 120Hz', price: 1199.99, stock: 6, category: 'Electrónica', image_url: 'https://via.placeholder.com/400x300?text=Smart+TV' },
  { name: 'Mochila Laptop 17" Resistente', description: 'Mochila premium anti-robo con compartimento acolchado y carga USB', price: 79.99, stock: 35, category: 'Accesorios', image_url: 'https://via.placeholder.com/400x300?text=Mochila' },
];

module.exports = {
  async up(queryInterface) {
    const rows = products.map((p) => ({
      id: uuidv4(),
      ...p,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
    }));
    await queryInterface.bulkInsert('products', rows, {});
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('products', null, {});
  },
};
