/*=========================================================================================
        File Name: form-input-mask.js
        Description: Input Masks
        ----------------------------------------------------------------------------------------
        Item Name: Vuexy  - Vuejs, HTML & Laravel Admin Dashboard Template
        Author: Pixinvent
        Author URL: hhttp://www.themeforest.net/user/pixinvent
==========================================================================================*/

$(function () {
  'use strict';

  var phone_mask = $('.phone-mask');

    // phone
    if (phone_mask.length) {
        new Cleave(phone_mask, {
            prefix: '+998',
            blocks: [4, 2, 3, 2, 2],
            uppercase: true,
            // phone: true,
        });
    }

});
