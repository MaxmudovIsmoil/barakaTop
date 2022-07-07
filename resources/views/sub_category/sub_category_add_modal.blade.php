<div class="modal fade modal-primary text-left" id="sub_category_add_modal" tabindex="-1" data-backdrop="static" role="dialog" aria-labelledby="deleteModalMabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Ichki kategoriya qo'shish</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="" method="POST" id="js_sub_category_form_add" name="sub_category_form_add" enctype="multipart/form-data">
                <div class="modal-body">
                    @csrf
                    <div>
                        <label>Do'konni tanlang</label>
                        <select class="form-control js_sub_category js_partner_id select2" name="partner_id">
                            <option value="0">---</option>
                            @foreach($partner as $p)
                                <option value="{{ $p->id }}">{{ $p->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div style="margin-top: 10px;">
                        <label for="name">Nomi</label>
                        <input type="text" name="name" id="name" class="js_name form-control" />
                        <div class="invalid-feedback">Nomini kiriting!</div>
                    </div>
                    <div class="input-field mt-1">
                        <div class="sub-category-image" style="padding-top: .5rem;"></div>
                        <div class="js_images_invalid text-danger d-none">Rasmni yuklang!</div>
                    </div>
                </div>
                <div class="modal-footer">
                    <input type="submit" value="Saqlash" class="btn btn-outline-success" />
                    <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Bekor qilish</button>
                </div>
            </form>
        </div>
    </div>
</div>
