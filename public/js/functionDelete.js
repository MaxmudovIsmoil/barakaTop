$(document).ready(function(){

    var deleteModal = $(document).find('#deleteModal')

    $(document).on("click", ".js_delete_btn", function () {

        let name = $(this).data('name')
        let url = $(this).data('url')

        deleteModal.find('.modal-title').html(name)

        let form = deleteModal.find('#js_modal_delete_form')
        form.attr('action', url)
        deleteModal.modal('show');

    });

    /* delete form submit */
    $(document).on('submit', '#js_modal_delete_form', function (e) {
        e.preventDefault()

        let url = $(this).attr('action')
        let this_tr = $(document).find('.js_this_tr')

        $.ajax({
            type: "POST",
            url: url,
            data: $(this).serialize(),
            success: (response) => {

                if(!response.status) {
                    deleteModal.find('.js_message').addClass('d-none')
                    deleteModal.find('.js_danger').html(response.errors)
                }

                if(response.status) {
                    this_tr.each(function (item, arr) {
                        if($(arr).data('id') == response.id) {
                            let prev = $(arr).prev()
                            let next = $(arr).next()
                            if ((prev.hasClass('js_this_group') && next.hasClass('js_this_group')) || (prev.hasClass('js_this_group') && next.length === 0)) {
                                prev.remove()
                                arr.remove()
                            } else {
                                arr.remove()
                            }
                        }
                    })
                    deleteModal.modal('hide')
                }
            },
            error: (response) => {
                console.log('error:', response);
            }
        });

    });


    $('#deleteModal button[data-dismiss="modal"]').click(function() {

        deleteModal.find('.js_message').removeClass('d-none')
        deleteModal.find('.js_danger').html('')

    })


});



/** ================================================================================== **/
