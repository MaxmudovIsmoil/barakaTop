$(document).ready(function() {

    /** btn plus modal close inputs in clear **/
    $('#sub_category_add_modal button[data-dismiss="modal"]').click(function () {

        let form = $('#js_sub_category_form_add')

        let name = form.find('.js_name')
        name.val('')
        name.removeClass('is-invalid')
        name.siblings('.invalid-feedback').addClass('valid-feedback')

    })

    // $('.js_product_add_form button[data-dismiss="modal"]').click(function () {
    //
    //     let form = $('#js_add_from')
    //
    //     let name = form.find('.js_name')
    //     name.val('')
    //     name.removeClass('is-invalid')
    //     name.siblings('.invalid-feedback').addClass('valid-feedback')
    // })


    $('.js_name').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_username').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })


    $('.js_price').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_discount').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_phone').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_to').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_open_time').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_close_time').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_sum_min').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_sum_delivery').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_login').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_password').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    // Categoriya uchun
    $("#js_sub_category_form_add input[type='file']").on('change', function () {
        $('.js_images_invalid').addClass('d-none')
    });

    // Maxsulot uchun
    $(".js_product_add_form input[type='file']").on('change', function () {
        $('.js_product_image_invalid').addClass('d-none')
    });


    // Do'kon uchun
    $(".partner-image input[type='file']").on('change', function () {
        $('.js_partner_image_invalid').addClass('d-none')
    });

    $(".partner-background-image input[type='file']").on('change', function () {
        $('.js_background_image_invalid').addClass('d-none')
    });


    // statistic
    $('.js_start_date').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })

    $('.js_end_date').on('input', function () {
        $(this).removeClass('is-invalid')
        $(this).siblings('.invalid-feedback').addClass('valid-feedback')
    })
});
