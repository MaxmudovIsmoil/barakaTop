<div class="modal fade text-left" id="add_edit_modal" tabindex="-1" role="dialog" data-backdrop="static" aria-labelledby="myModalLabel33" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-centered" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h4 class="modal-title">Add & edit shop</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="{{ route('order.store') }}" method="POST" id="js_add_edit_from" data-type="store">
                @csrf
                @method('PUT')

                <input type="hidden" name="old_name">
                <div class="modal-body">
                    <div class="needs-validation">
                        <div class="row">
                            <div class="col-md-9">
                                <div class="row">
                                    <div class="col-md-3" style="padding-left: 8px;">
                                        <label>Do'konlar</label>
                                        <select class="form-control js_partner_id select2" name="partner_id">
                                            @foreach($partner as $p)
                                                <option value="{{ $p->id }}">{{ $p->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-md-4">
                                        <label>Kategoriyani tanlang</label>
                                        <select class="form-control js_sub_category select2" name="parent_id">
                                            <option value="0">---</option>
                                        </select>
                                    </div>
                                    <div class="col-md-5">
                                        <label>Nomi</label>
                                        <div class="form-group">
                                            <input type="text" name="name" class="form-control js_name" />
                                            <div class="invalid-feedback">Nomini kiriting!</div>
                                        </div>
                                    </div>
                                    <div class="col-md-12 div-card-product js_div_card_product"></div>
                                </div>
                            </div>
                            <div class="col-md-3 position-relative">
                                <div class="badge badge-light-primary product-savatcha-all-summ">
                                    <p>Jami: <span class="text-warning js_all_price">0</span> <i class="text-warning">so'm</i></p>
                                    <p>Miqdori: <span class="text-info js_all_count">0</span></p>
                                </div>
                                <div class="text-danger js_savatcha_error d-none position-absolute">Maxsulot tanlang!</div>
                                <div class="cash js_savatcha"></div>
                                <div class="client-div">
                                    <label for="prefix">Telefon raqami</label>
                                    <div class="form-group">
                                        <input type="text" name="phone" class="form-control js_phone phone-mask" id="prefix" />
                                        <div class="invalid-feedback">Relefon raqamni kiriting!</div>
                                    </div>

                                    <label for="client_name">Mijoz ismi</label>
                                    <div class="form-group position-relative">
                                        <input type="text" name="client_name" class="form-control js_client_name" id="client_name" />
                                        <i class="fas fa-pen client-name-edit-icon d-none"></i>
                                        <div class="invalid-feedback">Mijoz ismini kiriting!</div>
                                        <input type="hidden" name="client_id" class="js_client_id"/>
                                    </div>

                                    <label for="to">Manzili</label>
                                    <div class="form-group">
                                        <input type="text" name="to" id="to" class="form-control js_to" />
                                        <div class="invalid-feedback">Manzilni kiriting!</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer" style="padding-bottom: 0;">
                    <button type="button" class="btn btn-outline-success btn-sm js_form_save_btn">Saqlash</button>
                    <button type="button" class="btn btn-outline-secondary btn-sm js_form_close_btn" data-dismiss="modal">Bekor qilish</button>
                </div>
            </form>
        </div>
    </div>
</div>
