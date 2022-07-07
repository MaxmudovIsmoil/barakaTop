$(document).ready(function() {

    $(document).on('change', '.js_partner_id', function() {
        let partner_id = $(this).val()
        product_sub_category(partner_id)
    });

    $(document).on('click', '.js_btn_plus', function (e) {
        e.preventDefault()

        let modal = $('#sub_category_add_modal')
        let parent_id = $('.js_partner_id option:checked').val()

        modal.find('input[type="file"]').addClass('js_images')
        modal.find('.js_partner_id').val(parent_id)
        modal.modal('show')
    });

    $('.sub-category-image').imageUploader();

    // sub category add
    $(document).on('submit', '#js_sub_category_form_add', function(e) {
        e.preventDefault()

        let modal = $('#sub_category_add_modal')
        let form = $(this)
        let url = form.attr('action');
        let method = form.attr('method');
        let formData = new FormData(this);

        $.ajax({
            type: method,
            url: url,
            data: formData,
            contentType: false,
            processData: false,
            success: (response) => {

                if(!response.status) {
                    if(typeof response.errors !== 'undefined') {
                        if (response.errors.name)
                            form.find('.js_name').addClass('is-invalid')

                        if (response.errors.images)
                            $('.js_images_invalid').removeClass('d-none')
                    }
                }

                if (response.status) {
                    let partner_id = $('.js_partner_id option:selected').val()
                    product_sub_category(partner_id)
                    modal.modal('hide')
                }
            },
            error: (response) => {
                console.log(response);
            }
        });
    });



    // add product
    $(document).on('submit', '.js_product_add_form', function (e) {
        e.preventDefault()

        let form = $(this)
        let url = form.attr('action');
        let method = form.attr('method');
        let formData = new FormData(this);

        $.ajax({
            type: method,
            url: url,
            data: formData,
            contentType: false,
            processData: false,
            success: (response) => {

                if(!response.status) {
                    if(typeof response.errors !== 'undefined') {
                        if (response.errors.name)
                            form.find('.js_name').addClass('is-invalid')

                        if (response.errors.images)
                            $('.js_product_image_invalid').removeClass('d-none')

                        if (response.errors.price)
                            form.find('.js_price').addClass('is-invalid')

                        if (response.errors.discount)
                            form.find('.js_discount').addClass('is-invalid')
                    }
                }

                if (response.status) {
                    // show_check_icon()
                    Swal.fire({
                        title: 'Saqlandi',
                        icon: 'success',
                        customClass: {confirmButton: 'd-none'},
                        buttonsStyling: false
                    });

                    product_form_clear()
                    $(".product-image .delete-image").click()
                }
            },
            error: (response) => {
                console.log(response);
            }
        });

    });

})
