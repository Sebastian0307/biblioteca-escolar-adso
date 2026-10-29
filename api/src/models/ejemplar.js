const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Libro = require('./libro');

const Ejemplar = sequelize.define('ejemplares_libro', {
  id_ejemplar: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  id_libro: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Libro,
      key: 'id_libro'
    }
  },
  codigo_inventario: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true
  },
  condicion: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'bueno',
    validate: {
      isIn: [['bueno', 'regular']]
    }
  },
  disponibilidad: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'disponible',
    validate: {
      isIn: [['disponible', 'prestado', 'mantenimiento']]
    }
  }
}, {
  timestamps: false,
  freezeTableName: true
});

Libro.hasMany(Ejemplar, { foreignKey: 'id_libro', as: 'ejemplares', onDelete: 'CASCADE' });
Ejemplar.belongsTo(Libro, { foreignKey: 'id_libro', as: 'libro' });

module.exports = Ejemplar;
