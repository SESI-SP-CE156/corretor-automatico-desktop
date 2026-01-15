import sys
import os
import json
import traceback
import cv2
import numpy as np

# Configurar encoding para Windows
try:
    if sys.platform == "win32":
        sys.stdin.reconfigure(encoding='utf-8')
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

# Suprimir logs TF
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import tensorflow as tf
from tensorflow.keras.models import load_model
from ultralytics import YOLO

# --- CONSTANTES ---
IA_IMG_HEIGHT = 32
IA_IMG_WIDTH = 150
PADRAO_W = 600
PADRAO_H = 800
OFFSET_YOLO_X = 20
OFFSET_YOLO_Y = 21

# Globais
model_omr = None
model_yolo = None
labels_map = None
limites_colunas_detectados = {}

def carregar_modelos(paths):
    global model_omr, model_yolo, labels_map
    
    path_labels = paths.get("labels")
    if path_labels and os.path.exists(path_labels):
        try:
            with open(path_labels, 'r') as f:
                raw_labels = json.load(f)
            labels_map = {str(k): v for k, v in raw_labels.items()}
            sys.stderr.write(f"[INFO] Labels carregados: {labels_map}\n")
        except Exception as e:
            sys.stderr.write(f"[ERRO] Falha ao ler labels: {e}\n")
            labels_map = None
    
    if labels_map is None:
        labels_map = {"0": "A", "1": "B", "2": "C", "3": "D", "4": "E", "5": "NENHUMA"}

    path_omr = paths.get("omr")
    if model_omr is None and path_omr and os.path.exists(path_omr):
        try:
            model_omr = load_model(path_omr)
            sys.stderr.write("[INFO] Modelo OMR Keras carregado.\n")
        except Exception as e:
            sys.stderr.write(f"[ERRO] Falha ao carregar modelo Keras: {e}\n")
            model_omr = None

    path_yolo = paths.get("yolo")
    if model_yolo is None and path_yolo and os.path.exists(path_yolo):
        sys.stderr.write(f"[INFO] Carregando YOLO de: {path_yolo}\n")
        model_yolo = YOLO(path_yolo)

def aplicar_configuracao_inteligente(layout_config, gabarito_correto):
    total = layout_config.get('total_questoes')
    if not total and gabarito_correto:
        try:
            chaves = [int(k) for k in gabarito_correto.keys() if str(k).isdigit()]
            if chaves: total = max(chaves)
        except: pass
    if not total: total = 30
    layout_config['total_questoes'] = total

    if total == 28:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 14
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 32 
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 27
        sys.stderr.write("[INFO] PRESET: 28 QUESTÕES\n")
    elif total == 32:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 16
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 28
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 26
        sys.stderr.write("[INFO] PRESET: 32 QUESTÕES\n")
    else:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 15
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 30
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 26

    return layout_config

def atualizar_layout_com_yolo(img_clean, layout_atual, img_debug=None):
    global limites_colunas_detectados
    limites_colunas_detectados = {} 

    if model_yolo is None: return layout_atual

    try:
        results = model_yolo(img_clean, verbose=False)
        boxes_questoes = []

        for result in results:
            for box in result.boxes:
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])
                if cls_id == 0 and conf > 0.30: 
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    boxes_questoes.append((x1, y1, x2, y2))
        
        if not boxes_questoes:
            sys.stderr.write("[WARN] YOLO: Nenhuma coluna detectada. Usando layout fixo.\n")
            return layout_atual

        boxes_questoes.sort(key=lambda b: b[0])
        soma_alturas = 0
        qtd_colunas_detectadas = 0

        # Não desenha mais caixas azuis no modo final, apenas usa para cálculo
        # if img_debug is not None: ...

        if len(boxes_questoes) >= 1:
            x1, y1, x2, y2 = boxes_questoes[0]
            layout_atual['coluna_1_origem_xy'] = [int(x1 + OFFSET_YOLO_X), int(y1 + OFFSET_YOLO_Y)]
            soma_alturas += (y2 - y1)
            qtd_colunas_detectadas += 1
            limites_colunas_detectados[0] = (x1, y1, x2, y2) 
        
        if len(boxes_questoes) >= 2:
            x1, y1, x2, y2 = boxes_questoes[-1]
            layout_atual['coluna_2_origem_xy'] = [int(x1 + OFFSET_YOLO_X), int(y1 + OFFSET_YOLO_Y)]
            soma_alturas += (y2 - y1)
            qtd_colunas_detectadas += 1
            limites_colunas_detectados[1] = (x1, y1, x2, y2)

        if qtd_colunas_detectadas > 0:
            altura_media = soma_alturas / qtd_colunas_detectadas
            q_por_col = layout_atual.get('questoes_por_coluna', 15)
            if q_por_col > 0:
                novo_espaco_v = (altura_media / q_por_col) * 0.98
                layout_atual['espaco_v_bolha'] = novo_espaco_v
                sys.stderr.write(f"[INFO] YOLO: Espaçamento ajustado para {novo_espaco_v:.2f}px\n")

        return layout_atual

    except Exception as e:
        sys.stderr.write(f"[ERRO] Falha no YOLO: {e}\n")
        return layout_atual

def _get_crop_para_questao(thresh_img, num_questao_atual, layout):
    q_por_col = layout.get('questoes_por_coluna', 15)
    raio = layout.get('raio_bolha', 6)
    col1 = layout.get('coluna_1_origem_xy') or [0,0]
    col2 = layout.get('coluna_2_origem_xy') or [0,0]
    origens = [col1, col2]
    
    espaco_h = layout.get('espaco_h_bolha', 28)
    espaco_v = layout.get('espaco_v_bolha', 26)

    padding_v = int(raio * 1.4) 
    padding_h = int(raio * 1.4)
    
    if num_questao_atual <= q_por_col:
        col_idx = 0
        q_idx = num_questao_atual - 1
    else:
        col_idx = 1
        q_idx = num_questao_atual - q_por_col - 1
    
    if col_idx >= len(origens): return None, None

    origem_x, origem_y = origens[col_idx]
    if origem_x == 0 and origem_y == 0: return None, None

    y_centro = int(origem_y + (q_idx * espaco_v))
    x_A = int(origem_x)
    x_E = int(origem_x + (4 * espaco_h))
    
    y1 = y_centro - padding_v
    y2 = y_centro + padding_v
    x1 = x_A - padding_h
    x2 = x_E + padding_h
    
    limites = limites_colunas_detectados.get(col_idx)
    if limites:
        bx1, by1, bx2, by2 = limites
        y1 = max(y1, by1)
        y2 = min(y2, by2)
        x1 = max(x1, bx1) 
        x2 = min(x2, bx2)

    h_img, w_img = thresh_img.shape
    y1 = max(0, y1); y2 = min(h_img, y2)
    x1 = max(0, x1); x2 = min(w_img, x2)
    
    if y2 <= y1 or x2 <= x1: return None, None

    return thresh_img[y1:y2, x1:x2], (x1, y1, x2, y2, y_centro)

def ler_por_pixel_count(crop_thresh, num_opcoes=5):
    h, w = crop_thresh.shape
    step = w // num_opcoes
    pixels = []
    for i in range(num_opcoes):
        x_start = i * step
        x_end = (i + 1) * step
        roi = crop_thresh[:, x_start:x_end]
        total = cv2.countNonZero(roi)
        pixels.append(total)
    
    LIMIT = 50 
    max_pixels = max(pixels)
    if max_pixels > LIMIT:
        idx_max = np.argmax(pixels)
        return str(idx_max)
    return "5"

def processar_prova(imagem_path, layout_config, gabarito_correto, model_paths):
    carregar_modelos(model_paths)
    
    img_array = np.fromfile(imagem_path, np.uint8)
    img_orig = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    if img_orig is None: return {"sucesso": False, "erro": "Falha ao ler imagem"}

    planificada = cv2.resize(img_orig, (PADRAO_W, PADRAO_H), interpolation=cv2.INTER_AREA)
    img_out = planificada.copy() # Imagem para desenho limpa (sem caixas de debug)

    layout_config = aplicar_configuracao_inteligente(layout_config, gabarito_correto)
    # Passamos None para img_debug no update layout para NÃO desenhar caixas de debug na img final
    layout_config = atualizar_layout_com_yolo(planificada, layout_config, img_debug=None)

    gray = cv2.cvtColor(planificada, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)[1]

    batch_imgs = []
    mapa_indices = []
    respostas_detectadas = {}
    
    total_questoes = layout_config.get('total_questoes', 30)

    for q_num in range(1, total_questoes + 1):
        crop, coords = _get_crop_para_questao(thresh, q_num, layout_config)
        # Não desenhamos mais retângulos laranjas aqui (modo produção)

        if crop is not None and crop.size > 0 and crop.shape[0] > 5 and crop.shape[1] > 5:
            try:
                crop_resized = cv2.resize(crop, (IA_IMG_WIDTH, IA_IMG_HEIGHT))
                crop_norm = crop_resized.astype("float32") / 255.0
                crop_expanded = np.expand_dims(crop_norm, axis=-1)
                batch_imgs.append(crop_expanded)
                mapa_indices.append(q_num)
            except Exception:
                respostas_detectadas[str(q_num)] = "ERRO"
        else:
            respostas_detectadas[str(q_num)] = "VAZIO"

    acertos = 0
    usou_ia = False

    if batch_imgs and model_omr:
        try:
            batch_array = np.array(batch_imgs)
            predictions = model_omr.predict(batch_array, verbose=0)
            usou_ia = True
            for i, pred_vector in enumerate(predictions):
                q_num = mapa_indices[i]
                idx_max = np.argmax(pred_vector)
                letra = labels_map.get(str(idx_max), "UNK")
                if letra == "NENHUMA": letra = "VAZIO"
                respostas_detectadas[str(q_num)] = letra
        except Exception as e:
            sys.stderr.write(f"[ERRO IA] {e}. Fallback Pixel Count.\n")
            for i, idx_q in enumerate(mapa_indices):
                crop, _ = _get_crop_para_questao(thresh, idx_q, layout_config)
                if crop is not None:
                    idx_pixel = ler_por_pixel_count(crop)
                    letra = labels_map.get(idx_pixel, "VAZIO")
                    if letra == "NENHUMA": letra = "VAZIO"
                    respostas_detectadas[str(idx_q)] = letra

    if not usou_ia and not respostas_detectadas:
         for q_num in mapa_indices:
            crop, _ = _get_crop_para_questao(thresh, q_num, layout_config)
            if crop is not None:
                idx_pixel = ler_por_pixel_count(crop)
                letra = labels_map.get(idx_pixel, "VAZIO")
                if letra == "NENHUMA": letra = "VAZIO"
                respostas_detectadas[str(q_num)] = letra

    # --- DESENHO DO FEEDBACK (ANÉIS) ---
    letras = ["A", "B", "C", "D", "E"]
    
    for q_num_str, letra_aluno in respostas_detectadas.items():
        q_num = int(q_num_str)
        
        # Recupera dados de posição
        q_por_col = layout_config.get('questoes_por_coluna', 15)
        espaco_h = layout_config.get('espaco_h_bolha', 28)
        espaco_v = layout_config.get('espaco_v_bolha', 26)
        col_idx = 0 if q_num <= q_por_col else 1
        q_idx = (q_num - 1) if col_idx == 0 else (q_num - q_por_col - 1)
        origens = [layout_config.get('coluna_1_origem_xy'), layout_config.get('coluna_2_origem_xy')]
        
        if origens[col_idx]:
            ox, oy = origens[col_idx]
            y_pos = int(oy + (q_idx * espaco_v))
            
            # Gabarito oficial para esta questão
            letra_gabarito = gabarito_correto.get(str(q_num)) if gabarito_correto else None
            
            # Lógica de Cor e Desenho
            
            # 1. Se aluno respondeu (A-E)
            if letra_aluno in letras:
                l_idx = letras.index(letra_aluno)
                x_pos = int(ox + (l_idx * espaco_h))
                
                if letra_gabarito:
                    if letra_aluno == letra_gabarito:
                        # Acertou: Anel Verde
                        cv2.circle(img_out, (x_pos, y_pos), 10, (0, 255, 0), 2) # Thickness 2 = Anel
                        acertos += 1
                    else:
                        # Errou: Anel Vermelho na marcada
                        cv2.circle(img_out, (x_pos, y_pos), 10, (0, 0, 255), 2)
                else:
                    # Sem gabarito: Apenas marca o que leu em Vermelho (ou outra cor neutra se preferir)
                    cv2.circle(img_out, (x_pos, y_pos), 10, (0, 0, 255), 2)

            # 2. Se errou ou não respondeu, mostrar qual era a certa (Anel Azul)
            if letra_gabarito and letra_gabarito in letras:
                if letra_aluno != letra_gabarito:
                    # Desenha anel azul na correta
                    l_idx_gab = letras.index(letra_gabarito)
                    x_pos_gab = int(ox + (l_idx_gab * espaco_h))
                    cv2.circle(img_out, (x_pos_gab, y_pos), 10, (255, 0, 0), 2) # Azul (BGR)

    out_path = os.path.join(os.path.dirname(imagem_path), f"checked_{os.path.basename(imagem_path)}")
    cv2.imwrite(out_path, img_out)

    return {
        "sucesso": True,
        "caminho_imagem_corrigida": out_path,
        "respostas_detectadas": respostas_detectadas,
        "acertos": acertos,
        "total_questoes": total_questoes
    }

if __name__ == "__main__":
    try:
        input_data = sys.stdin.read()
        if not input_data: sys.exit(1)
        dados = json.loads(input_data)
        res = processar_prova(dados["caminho_imagem"], dados["layout_config"], dados["gabarito"], dados.get("model_paths", {}))
        print(json.dumps(res))
    except Exception as e:
        print(json.dumps({"sucesso": False, "erro": str(e), "trace": traceback.format_exc()}))