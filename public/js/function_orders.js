
var table = null;
function create_datatable(url) {
    let status = url.substr(url.length-1, 1)

    if (table != null){
        table.destroy()
        $('#datatable tbody').empty()
        $('#datatable thead').empty()
    }
    $('#dataTable thead').html(create_thead_in_datatable(status))

    table =  $('#datatable').DataTable({
        paging: true,
        pageLength: 20,
        lengthChange: false,
        searching: true,
        ordering: true,
        info: true,
        autoWidth: true,
        language: {
            search: "",
            searchPlaceholder: " Izlash...",
            sLengthMenu: "Кўриш _MENU_ тадан",
            sInfo: "Ko'rish _START_ dan _END_ gacha _TOTAL_ jami",
            emptyTable: "Ma'lumot mavjud emas",
            sInfoFiltered: "(Jami _MAX_ ta yozuvdan filtrlangan)",
            sZeroRecords: "Hech qanday mos yozuvlar topilmadi",
            oPaginate: {
                sNext: "Keyingi",
                sPrevious: "Oldingi",
            },
        },
        processing: true,
        serverSide: true,
        ajax: {
            "url": url,
        },
        columns: create_column_in_datatable(status),
    });
    return table;
}

function create_column_in_datatable(status) {
    if (status == 1) {
        return [
            {data: 'DT_RowIndex'},
            {data: 'client_name'},
            {data: 'phone'},
            {data: 'address'},
            {data: 'summa'},
            {data: 'status'},
            {data: 'date_created'},
            {data: 'action', name: 'action', orderable: false, searchable: false}
        ];
    }
    else if(status == 2) {
        return [
            {data: 'DT_RowIndex'},
            {data: 'client_name'},
            {data: 'phone'},
            {data: 'address'},
            {data: 'summa'},
            {data: 'comments'},
            {data: 'date_created'},
            {data: 'action', name: 'action', orderable: false, searchable: false}
        ];
    }
    else if (status == 3) {
        return [
            {data: 'DT_RowIndex'},
            {data: 'client_name'},
            {data: 'phone'},
            {data: 'address'},
            {data: 'summa'},
            {data: 'date_created'},
            {data: 'action', name: 'action', orderable: false, searchable: false}
        ];
    }
}

function create_thead_in_datatable(status) {
    let tr = ''
    if (status == 1)
        tr = '<th>Status</th>'
    else if(status == 2)
        tr = '<th>Izoh</th>'

    return '<tr>\n' +
                '<th>№</th>\n' +
                '<th>Mijoz</th>\n' +
                '<th>Telefon raqam</th>\n' +
                '<th>Nanzil (dan, ga)</th>\n' +
                '<th>summa</th>\n'+
                    tr+
                '<th>Tushgan vaqt</th>\n' +
                '<th class="text-right">Harakatlar</th>\n' +
            '</tr>';
}

function form_clear(form) {
    form.find('.js_name').val('')
    form.find('.js_phone').val('')
    form.find('.js_client_name').val('')
    form.find('.js_to').val('')
}



function create_card_product_at_content_div(response) {
    let product = '', img = '', product_name = ''
    for(let i = 0; i < response.product.length; i ++) {
        if (response.product[i].image)
            img = window.location.protocol + "//" + window.location.host + response.product[i].image;
        else
            img = window.location.protocol + "//" + window.location.host +"/images/nophoto.png";


        if (response.product[i].name.length > 20)
            product_name = response.product[i].name.substr(0, 20).replace('"', '\"') + " .. ";
        else
            product_name = response.product[i].name.replaceAll('"', '\"');

        let data_product_name = response.product[i].name.replaceAll('"', '\"').replaceAll("'", "\'");

        product += '<div class="card card-product js_card_product" ' +
                        'data-product_id="'+response.product[i].id+'"' +
                        'title="'+data_product_name+'">\n' +
                        '<img class="card-img-top product-image" src="' + img + '" alt="no photo" />\n' +
                        '<div class="product-name-price badge badge-light-primary">\n' +
                            '<p class="text-info card-product-name">' + product_name + '</p>\n' +
                            '<p class="d-none">' + data_product_name + '</p>\n' +
                            '<p class="text-warning card-product-price" data-price="'+response.product[i].price+'">' +
                                '<span>' + number_format(response.product[i].price) + '</span> so\'m' +
                            '</p>\n' +
                        '</div>\n' +
                    '</div>';
    }
    $('.js_div_card_product').html(product);
}

function create_card_product_at_modal(partner_id, parent_id) {
    let url = window.location.protocol + "//" + window.location.host + "/order/get-product/"+partner_id+"/"+parent_id;
    $.ajax({
        type: 'GET',
        url: url,
        dataType: 'JSON',
        success: (response) => {

            console.log('res: ', response)
            if(response.status) {
                create_card_product_at_content_div(response)
            }
        },
        error: (response) => {
            console.log('error: ', response)
        }
    })
}

function create_card_product_search_product_name(partner_id, parent_id, name, token) {
    let url = window.location.protocol + "//" + window.location.host + "/order/get-product-search/";
    let data = {
        '_token': token,
        'partner_id': partner_id,
        'parent_id': parent_id,
        'name': name,
    }
    $.ajax({
        url: url,
        type: 'POST',
        data: data,
        dataType: 'JSON',
        success: (response) => {

            console.log('res: ', response)
            if(response.status) {
                create_card_product_at_content_div(response)
            }
        },
        error: (response) => {
            console.log('error: ', response)
        }
    })
}


function savatchaga_yangi_maxsulot_qoshish(product_id, name, price, quantity = 1) {

    let html = '<div class="card product-cash js_product_cash" data-product_id="'+product_id+'" data-price="'+price+'">\n' +
                    '<i class="fas fa-times js_product_cash_remove_btn"></i>\n' +
                    '<p class="text-primary">' + name + '</p>\n' +
                    '<div class="pirce-btn">\n' +
                        '<p class="text-warning product-cash-price"><span>' + number_format(price) + '</span> so\'m</p>\n' +
                        '<div class="input-group quantity-counter-wrapper bootstrap-touchspin">\n' +
                            '<span class="input-group-btn input-group-prepend bootstrap-touchspin-injected">\n' +
                                '<button class="btn btn-primary btn-lg bootstrap-touchspin-down waves-effect waves-float waves-light js_kamaytirish_btn" type="button">-</button>\n' +
                            '</span>\n' +
                            '<input type="number" class="quantity-counter form-control valid js_product_count" value="'+quantity+'">\n' +
                            '<span class="input-group-btn input-group-append bootstrap-touchspin-injected">\n' +
                                '<button class="btn btn-primary btn-lg bootstrap-touchspin-up waves-effect waves-float waves-light js_oshirish_btn" type="button">+</button>\n' +
                            '</span>\n' +
                        '</div>\n' +
                    '</div>\n' +
                '</div>';

    let savatcha_maxsulotlari = $('.js_savatcha .js_product_cash')
    let check = true, count;

    $.each(savatcha_maxsulotlari, function(index, item) {

        if ($(item).data('product_id') === product_id) {
            count = $(item).find('.js_product_count').val()
            count++;
            $(item).find('.js_product_count').val(count)
            check = false;
        }
    })

    if (check)
        $('.js_savatcha').append(html)

}

function savatchadagi_maxsulotlar_taxrirlash_uchun(order_details) {

    console.log('ord_det: ', order_details)
    for (let i = 0; i < order_details.length; i++) {
        savatchaga_yangi_maxsulot_qoshish(order_details[i].product_id, order_details[i].product.name, order_details[i].price, order_details[i].quantity)

        let card_product = $('.js_card_product');
        $.each(card_product, function(index, item) {

            if ($(item).data('product_id') === order_details[i].product_id) {
                $(item).addClass('product-add')
            }
        })
    }
    savatchadagi_barcha_summa_va_soni()
}


function savatchadagi_barcha_summa_va_soni() {

    let product_cash = $('.js_savatcha .js_product_cash')
    let jami_summa = 0, jami_soni = 0;
    $.each(product_cash, function(i, item) {
        let price = $(item).data('price')
        let count = $(item).find('.js_product_count').val() * 1
        jami_summa += price * count
        jami_soni += count
    });
    $('.js_all_price').html(number_format(jami_summa))
    $('.js_all_count').html(jami_soni)
}




function savatchadagi_kamaytirish_btn(product_cash) {

    let count = product_cash.find('.js_product_count').val()
    if (count > 1) {
        count--
        product_cash.find('.js_product_count').val(count)
        savatchadagi_barcha_summa_va_soni()
    }
}


function savatchadagi_oshirish_btn(product_cash) {

    let count = product_cash.find('.js_product_count').val()
    if (count < 20) {
        count++
        product_cash.find('.js_product_count').val(count)
        savatchadagi_barcha_summa_va_soni()
    }
}


function savatchadan_ochirish(product_id) {

    let product_cash = $('.js_savatcha .js_product_cash')

    $.each(product_cash, function(i, item) {
        if ($(item).data('product_id') === product_id) {
            $(item).remove()
            savatchadagi_barcha_summa_va_soni()
        }
    })

    let card_product = $('.js_div_card_product .js_card_product')
    $.each(card_product, function(i, item) {
        if ($(item).data('product_id') === product_id) {
            $(item).removeClass('product-add')
        }
    })

}


function mijoz_bazada_bolsa_ismini_olish(phone) {
    phone = phone.replaceAll(' ', '')
    let client_name = $('.js_client_name')
    let token = $('input[name="_token"]').val()

    console.log(token)
    phone = phone.substr(4, 9);

    if (phone.length >= 9) {
        $.ajax({
            type: 'POST',
            url:  window.location.protocol + "//" + window.location.host + '/order/get-client-name/',
            dataType: 'JSON',
            data: { '_token': token, 'phone': phone },
            success: (response) => {
                console.log(response)

                if (response.status && response.client != null) {
                    $('.js_client_id').val(response.client.id)
                    if (response.client.name) {
                        client_name.val(response.client.name)
                        client_name.attr('client_old_name', response.client.name)
                        client_name.attr('readonly',true)
                        client_name.siblings('.client-name-edit-icon').removeClass('d-none')
                    }
                }
                else if(response.client == null) {
                    client_name.attr('readonly',false)
                    client_name.val('')
                    client_name.attr('placeholder','Yangi mijoz')
                }

            },
            error: (response) => {
                console.log('error: ', response)
            }
        })
    }
}

function buyurtmani_saqlash() {
    let form    = $('#js_add_edit_from')
    let url     = form.attr('action');
    let _token  = form.find('input[name="_token"]').val()
    let phone   = form.find(".js_phone").val()
    let old_phone   = form.find(".js_phone").attr('old_phone')
    let client_name = form.find(".js_client_name").val()
    let client_old_name = form.find(".js_client_name").attr('client_old_name')
    let client_id = form.find(".js_client_id").val()
    let to      = form.find(".js_to").val()
    let partner_id  = form.find('.js_partner_id').val()
    let parent_id   = form.find('.js_sub_category').val()
    let savatchadagilar = form.find('.js_savatcha .js_product_cash')

    let orders = {}, order;

    $.each(savatchadagilar, function(i, item) {

        order = {
                'product_id': $(item).data('product_id'),
                'name'      : $(item).find('.text-primary').html(),
                'price'     : $(item).data('price'),
                'quantity'  : $(item).find('.js_product_count').val(),
            }
        orders[i] = order

    })
    let data = {
        '_token': _token,
        'phone': phone.replaceAll(" ", ""),
        'old_phone': (old_phone) ? old_phone.replaceAll(" ", "") : '',
        'client_name': client_name,
        'client_old_name': (client_old_name) ? client_old_name : '',
        'client_id': client_id,
        'to': to,
        'partner_id': partner_id,
        'parent_id': parent_id,
        'orders': orders,
    }

    let type = form.data('type')
    if (type === 'update') {
        data._method = 'PUT'
    }

    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        dataType: "JSON",
        success: (response) => {

            console.log(response)
            if (response.status) {
                location.reload()
            }
            else {
                if(typeof response.errors !== 'undefined') {
                    if (response.errors.orders)
                        $('.js_savatcha_error').removeClass('d-none')

                    if (response.errors.phone)
                        $('.js_phone').addClass('is-invalid')

                    if (response.errors.to)
                        $('.js_to').addClass('is-invalid')
                }
            }
        },
        error: (response) => {
            console.log('error: ', response)
        }
    })

}


/** order status update btn icons **/
function buyurtma_status_ozgartirish_btn_icons_uchun(url, status, order_table) {
    let token = $('input[name="_token"]').val()

    $.ajax({
        url: url,
        type: "POST",
        dataType: 'JSON',
        data: { '_token': token, 'status' : status },
        success: (response) => {
            console.log(response)
            if (response.status)
                order_table.draw()
        },
        error: (response) => {
            console.log('error: ', response)
        },
    })

}
