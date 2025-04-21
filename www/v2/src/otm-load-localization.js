////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-load-localization.js
//
// Localization JSON loader -> global ui.loc
//
// V 2.00 - 05.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { get as axiosget } from 'axios';
import { ui } from '../src/index.js';

// async localization loader
// =========================
function otm_load_localization(success, error) {

  axiosget(OTM_ENV_BROWSERPATH + 'l/lang.json')
    .then(({
      data
    }) => {
      ui.lang = data;
      axiosget(OTM_ENV_BROWSERPATH + 'l/' + ui.ctx.language + '.json')
        .then(({
          data
        }) => {
          ui.loc = data;
          success();
        })
        .catch((err) => {
          console.log(err);
          error();
        })
    })
    .catch((err) => {
      console.log(err);
      error();
    })
}

// our exports
// ===========
export { otm_load_localization };
