import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

import { IThemeManager } from '@jupyterlab/apputils';

/**
 * Initialization data for the galaxalabs_jupyterlab_steel_dark_theme extension.
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: 'galaxalabs_jupyterlab_steel_dark_theme:plugin',
  description:
    'Dark theme based on Sublime text editor default dark theme, tweaked by Stellars',
  autoStart: true,
  requires: [IThemeManager],
  activate: (app: JupyterFrontEnd, manager: IThemeManager) => {
    console.log(
      'JupyterLab extension galaxalabs_jupyterlab_steel_dark_theme is activated!'
    );
    const style = 'galaxalabs_jupyterlab_steel_dark_theme/index.css';

    manager.register({
      name: 'Galaxa Dark Theme - Steel',
      themeScrollbars: true,
      isLight: false,
      load: () => manager.loadCSS(style),
      unload: () => Promise.resolve(undefined)
    });
  }
};

export default plugin;
