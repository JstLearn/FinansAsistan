import { AppRegistry } from 'react-native';
import App from './front';
import { name as appName } from './app.json';

// Development modunda başlangıç logu
if (process.env.NODE_ENV === 'development') {
  console.log('React uygulaması başlatılıyor...');
}

AppRegistry.registerComponent(appName, () => App);

AppRegistry.runApplication(appName, {
  initialProps: {},
  rootTag: document.getElementById('root'),
});
