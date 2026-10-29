const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Usuario = sequelize.define('usuarios', {
  id_usuario: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  nombre: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  apellido: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  documento: {
    type: DataTypes.STRING(30),
    allowNull: false,
    unique: true
  },
  tipo_usuario: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'estudiante',
    validate: {
      isIn: [['estudiante', 'profesor', 'administrador', 'administrativo', 'bibliotecario']]
    }
  }
}, {
  timestamps: false,
  freezeTableName: true
});

module.exports = Usuario;
